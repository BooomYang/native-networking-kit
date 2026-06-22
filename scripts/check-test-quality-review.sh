#!/usr/bin/env bash
set -euo pipefail

node <<'NODE'
const fs = require("fs");
const https = require("https");

const marker = "TEST_QUALITY_CONFIRMED";
const relevantPatterns = [
  /(^|\/)(Tests|tests|test|androidTest|ohosTest|Harnesses)\//,
  /(^|\/)[^/]*(Test|Tests)\.[^/]+$/,
  /(^|\/)[^/]*\.spec\.[^/]+$/,
  /(^|\/)AndroidManifest\.xml$/,
  /(^|\/)(oh-package\.json5|module\.json5)$/,
  /^\.github\/workflows\//,
  /^README\.md$/,
  /^platforms\/[^/]+\/README\.md$/,
  /(^|\/)(Package\.swift|build\.gradle\.kts|settings\.gradle\.kts|hvigorfile\.ts|build-profile\.json5)$/,
  /^platforms\/ios\/Examples\/.*\.xcodeproj\//,
  /^platforms\/android\/(gradle\.properties|gradlew|gradle\/wrapper\/gradle-wrapper\.(properties|jar))$/,
  /^scripts\/doctor\.sh$/,
  /^scripts\/verify-[^/]+\.sh$/,
  /^scripts\/check-test-quality-review\.sh$/,
  /^docs\/.*harness.*\.md$/i,
  /^docs\/review-guidelines\.md$/,
  /^docs\/testing-strategy\.md$/,
  /^docs\/verification-matrix\.md$/,
  /^AGENTS\.md$/,
];

function parseLocalChangedFiles() {
  const raw = process.env.TEST_QUALITY_CHANGED_FILES;
  if (!raw) return null;
  return raw.split(/\r?\n|,/).map((file) => file.trim()).filter(Boolean);
}

function relevantFiles(files) {
  return files.filter((file) => relevantPatterns.some((pattern) => pattern.test(file)));
}

function latestReviewByUser(reviews) {
  const latest = new Map();
  for (const review of reviews) {
    const login = review.user && review.user.login;
    if (!login) continue;
    latest.set(login, review);
  }
  return [...latest.values()];
}

function isMaintainerConfirmation(review, author, repoOwner) {
  const login = review.user && review.user.login;
  const body = review.body || "";
  const state = review.state || "";
  return (
    login &&
    (login === author || login === repoOwner) &&
    (state === "APPROVED" || state === "COMMENTED") &&
    body.includes(marker)
  );
}

function isMaintainerComment(comment, author, repoOwner) {
  const login = comment.user && comment.user.login;
  const body = comment.body || "";
  return login && (login === author || login === repoOwner) && body.includes(marker);
}

function hasMaintainerConfirmation(reviews, comments, author, repoOwner) {
  const hasReviewConfirmation = latestReviewByUser(reviews).some((review) => {
    return isMaintainerConfirmation(review, author, repoOwner);
  });
  const hasCommentConfirmation = comments.some((comment) => {
    return isMaintainerComment(comment, author, repoOwner);
  });
  return hasReviewConfirmation || hasCommentConfirmation;
}

function requestJson(path) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPOSITORY;
  if (!token || !repo) {
    throw new Error("GITHUB_TOKEN and GITHUB_REPOSITORY are required in PR context");
  }

  const options = {
    hostname: "api.github.com",
    path,
    method: "GET",
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "User-Agent": "native-networking-kit-test-quality-review",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`GitHub API ${res.statusCode}: ${body}`));
          return;
        }
        resolve(JSON.parse(body));
      });
    });
    req.on("error", reject);
    req.end();
  });
}

async function fetchPaged(pathPrefix) {
  const out = [];
  for (let page = 1; page <= 20; page += 1) {
    const separator = pathPrefix.includes("?") ? "&" : "?";
    const pageItems = await requestJson(`${pathPrefix}${separator}per_page=100&page=${page}`);
    out.push(...pageItems);
    if (pageItems.length < 100) break;
  }
  return out;
}

async function loadContext() {
  const localFiles = parseLocalChangedFiles();
  if (localFiles) {
    return {
      author: process.env.TEST_QUALITY_PR_AUTHOR || "author",
      repoOwner: process.env.TEST_QUALITY_REPO_OWNER || process.env.TEST_QUALITY_PR_AUTHOR || "author",
      files: localFiles,
      reviews: JSON.parse(process.env.TEST_QUALITY_REVIEWS_JSON || "[]"),
      comments: JSON.parse(process.env.TEST_QUALITY_COMMENTS_JSON || "[]"),
    };
  }

  const eventPath = process.env.GITHUB_EVENT_PATH;
  if (!eventPath || !fs.existsSync(eventPath)) {
    return null;
  }

  const event = JSON.parse(fs.readFileSync(eventPath, "utf8"));
  const pullRequest = event.pull_request || null;
  const issue = event.issue || null;
  if (!pullRequest && !(issue && issue.pull_request)) {
    return null;
  }

  const repo = process.env.GITHUB_REPOSITORY;
  const prNumber = pullRequest ? pullRequest.number : issue.number;
  const pr = pullRequest || await requestJson(`/repos/${repo}/pulls/${prNumber}`);
  return {
    author: pr.user.login,
    repoOwner: repo.split("/")[0],
    files: (await fetchPaged(`/repos/${repo}/pulls/${prNumber}/files`)).map((file) => file.filename),
    reviews: await fetchPaged(`/repos/${repo}/pulls/${prNumber}/reviews`),
    comments: await fetchPaged(`/repos/${repo}/issues/${prNumber}/comments`),
  };
}

async function main() {
  const context = await loadContext();
  if (!context) {
    console.log("test-quality-review not required: no pull request context");
    return;
  }

  const files = relevantFiles(context.files);
  if (files.length === 0) {
    console.log("test-quality-review not required: no test/harness/verification files changed");
    return;
  }

  if (hasMaintainerConfirmation(context.reviews, context.comments, context.author, context.repoOwner)) {
    console.log(`test-quality-review passed: maintainer confirmation with ${marker}`);
    return;
  }

  console.error("test-quality-review required but missing.");
  console.error(`Changed files:\n${files.map((file) => `- ${file}`).join("\n")}`);
  console.error(`Need maintainer GitHub PR review or conversation comment whose body includes ${marker}.`);
  console.error("Solo-maintainer repos may use the PR author's review/comment; AI agents must not add this marker for the maintainer.");
  process.exit(1);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
NODE
