#!/usr/bin/env bash
set -euo pipefail

node <<'NODE'
const fs = require("fs");
const https = require("https");

const attentionLabels = ["attention:none", "attention:ai-fixable", "attention:human"];
const routerSummaryMarker = "<!-- native-netkit-review-attention-router -->";
const severityRank = { P0: 4, P1: 3, P2: 2, P3: 1 };
const hotZonePatterns = [
  { label: "hot-zone:api", pattern: /(^|\/)(Sources|src\/main|oh_modules|native-netkit).*(NativeNet(Client|HttpEngine|Request|Response|NetworkError)|HttpEngine|Request|Response|NetworkError)/ },
  { label: "hot-zone:harness", pattern: /(^|\/)(Tests|tests|test|androidTest|ohosTest|Harnesses)\// },
  { label: "hot-zone:harness", pattern: /^scripts\/(verify-[^/]+|doctor|check-test-quality-review)\.sh$/ },
  { label: "hot-zone:harness", pattern: /^\.github\/workflows\// },
  { label: "hot-zone:package", pattern: /(^|\/)(Package\.swift|build\.gradle\.kts|settings\.gradle\.kts|gradle\.properties|hvigorfile\.ts|build-profile\.json5|oh-package\.json5|module\.json5|AndroidManifest\.xml)$/ },
  { label: "hot-zone:package", pattern: /^platforms\/ios\/Examples\/.*\.xcodeproj\// },
  { label: "hot-zone:package", pattern: /^platforms\/android\/(gradlew|gradle\/wrapper\/gradle-wrapper\.(properties|jar))$/ },
  { label: "hot-zone:docs", pattern: /^README\.md$/ },
  { label: "hot-zone:docs", pattern: /^AGENTS\.md$/ },
  { label: "hot-zone:docs", pattern: /^platforms\/[^/]+\/README\.md$/ },
  { label: "hot-zone:docs", pattern: /^docs\/(review-guidelines|testing-strategy|verification-matrix|.*harness.*)\.md$/i },
];

function parseLocalChangedFiles() {
  const raw = process.env.REVIEW_ROUTER_CHANGED_FILES;
  if (!raw) return null;
  return raw.split(/\r?\n|,/).map((file) => file.trim()).filter(Boolean);
}

function parseJsonEnv(name) {
  return JSON.parse(process.env[name] || "[]");
}

function hotZoneLabelsForFile(file) {
  return hotZonePatterns
    .filter((item) => item.pattern.test(file))
    .map((item) => item.label);
}

function unique(values) {
  return [...new Set(values)];
}

function extractSeverity(text) {
  const body = text || "";
  const match = body.match(/\bP[0-3]\b|P[0-3]\s+Badge/i);
  if (!match) return null;
  const normalized = match[0].toUpperCase().match(/P[0-3]/);
  return normalized ? normalized[0] : null;
}

function isActiveReview(review) {
  return (review.state || "").toUpperCase() !== "DISMISSED";
}

function isRouterSummaryComment(comment) {
  const body = comment.body || "";
  return body.includes(routerSummaryMarker) || /^## Review attention router\b/m.test(body);
}

function isActiveReviewComment(comment) {
  return (comment.reviewState || "").toUpperCase() !== "DISMISSED";
}

function collectSignals(context) {
  const items = [
    ...context.reviews.filter(isActiveReview).map((review) => ({
      source: "review",
      author: review.user && review.user.login,
      body: review.body || "",
      path: review.path || "",
    })),
    ...context.reviewComments.filter(isActiveReviewComment).map((comment) => ({
      source: "review-comment",
      author: comment.user && comment.user.login,
      body: comment.body || "",
      path: comment.path || "",
    })),
    ...context.issueComments.filter((comment) => !isRouterSummaryComment(comment)).map((comment) => ({
      source: "issue-comment",
      author: comment.user && comment.user.login,
      body: comment.body || "",
      path: "",
    })),
  ];

  return items
    .map((item) => {
      const severity = extractSeverity(item.body);
      if (!severity) return null;
      return {
        ...item,
        severity,
        rank: severityRank[severity] || 0,
        hotZones: item.path ? hotZoneLabelsForFile(item.path) : [],
      };
    })
    .filter(Boolean);
}

function classify(context) {
  const changedHotZones = unique(context.files.flatMap(hotZoneLabelsForFile));
  const signals = collectSignals(context);
  const highestSignal = signals.reduce((best, item) => {
    if (!best || item.rank > best.rank) return item;
    return best;
  }, null);
  const hasP0P1 = signals.some((signal) => signal.rank >= severityRank.P1);
  const hasP2P3 = signals.some((signal) => signal.rank > 0);
  const signalHotZones = unique(signals.flatMap((signal) => signal.hotZones));
  const hasHotZone = changedHotZones.length > 0 || signalHotZones.length > 0;

  let attention = "attention:none";
  if (hasP0P1 && hasHotZone) {
    attention = "attention:human";
  } else if (hasP0P1 || hasP2P3) {
    attention = "attention:ai-fixable";
  }

  return {
    attention,
    changedHotZones,
    signalHotZones,
    signals,
    highestSeverity: highestSignal ? highestSignal.severity : "none",
  };
}

function requestJson(path, options = {}) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPOSITORY;
  if (!token || !repo) {
    throw new Error("GITHUB_TOKEN and GITHUB_REPOSITORY are required in PR context");
  }

  const body = options.body ? JSON.stringify(options.body) : undefined;
  const requestOptions = {
    hostname: "api.github.com",
    path,
    method: options.method || "GET",
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "User-Agent": "native-networking-kit-review-attention-router",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  };
  if (body) {
    requestOptions.headers["Content-Type"] = "application/json";
    requestOptions.headers["Content-Length"] = Buffer.byteLength(body);
  }

  return new Promise((resolve, reject) => {
    const req = https.request(requestOptions, (res) => {
      let responseBody = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        responseBody += chunk;
      });
      res.on("end", () => {
        if (res.statusCode === 204 || responseBody.length === 0) {
          resolve(null);
          return;
        }
        const parsed = JSON.parse(responseBody);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          const error = new Error(`GitHub API ${res.statusCode}: ${responseBody}`);
          error.statusCode = res.statusCode;
          error.response = parsed;
          reject(error);
          return;
        }
        resolve(parsed);
      });
    });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function requestGraphql(query, variables) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error("GITHUB_TOKEN is required in PR context");
  }

  const body = JSON.stringify({ query, variables });
  const requestOptions = {
    hostname: "api.github.com",
    path: "/graphql",
    method: "POST",
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "User-Agent": "native-networking-kit-review-attention-router",
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(requestOptions, (res) => {
      let responseBody = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        responseBody += chunk;
      });
      res.on("end", () => {
        const parsed = responseBody ? JSON.parse(responseBody) : null;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          const error = new Error(`GitHub GraphQL ${res.statusCode}: ${responseBody}`);
          error.statusCode = res.statusCode;
          error.response = parsed;
          reject(error);
          return;
        }
        if (parsed && parsed.errors) {
          reject(new Error(`GitHub GraphQL errors: ${JSON.stringify(parsed.errors)}`));
          return;
        }
        resolve(parsed ? parsed.data : null);
      });
    });
    req.on("error", reject);
    req.write(body);
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

async function fetchActiveReviewThreadComments(repo, prNumber) {
  const [owner, name] = repo.split("/");
  const query = `
    query($owner: String!, $name: String!, $number: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $after) {
            nodes {
              isResolved
              isOutdated
              comments(first: 100) {
                nodes {
                  body
                  path
                  author {
                    login
                  }
                  pullRequestReview {
                    state
                  }
                }
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }
  `;
  const comments = [];
  let after = null;
  for (let page = 1; page <= 20; page += 1) {
    const data = await requestGraphql(query, { owner, name, number: prNumber, after });
    const threads = data.repository.pullRequest.reviewThreads;
    for (const thread of threads.nodes) {
      if (thread.isResolved || thread.isOutdated) continue;
      for (const comment of thread.comments.nodes) {
        comments.push({
          body: comment.body || "",
          path: comment.path || "",
          user: comment.author ? { login: comment.author.login } : null,
          reviewState: comment.pullRequestReview ? comment.pullRequestReview.state : "",
        });
      }
    }
    if (!threads.pageInfo.hasNextPage) break;
    after = threads.pageInfo.endCursor;
  }
  return comments;
}

function annotateReviewCommentStates(comments, reviews) {
  const reviewStatesById = new Map(
    reviews
      .filter((review) => review.id !== undefined && review.id !== null)
      .map((review) => [String(review.id), review.state || ""])
  );
  return comments.map((comment) => ({
    ...comment,
    reviewState: reviewStatesById.get(String(comment.pull_request_review_id)) || "",
  }));
}

async function ensureLabel(repo, label) {
  const colors = {
    "attention:none": "c2e0c6",
    "attention:ai-fixable": "fef2c0",
    "attention:human": "d93f0b",
    "hot-zone:api": "b60205",
    "hot-zone:harness": "5319e7",
    "hot-zone:package": "1d76db",
    "hot-zone:docs": "0e8a16",
  };
  try {
    await requestJson(`/repos/${repo}/labels`, {
      method: "POST",
      body: {
        name: label,
        color: colors[label] || "ededed",
        description: label.startsWith("attention:")
          ? "Review attention routing result"
          : "Changed hot zone",
      },
    });
  } catch (error) {
    if (error.statusCode !== 422) throw error;
  }
}

async function deleteLabel(repo, prNumber, label) {
  try {
    await requestJson(`/repos/${repo}/issues/${prNumber}/labels/${encodeURIComponent(label)}`, {
      method: "DELETE",
    });
  } catch (error) {
    if (error.statusCode !== 404) {
      console.warn(`[warning] could not remove label ${label}: ${error.message}`);
    }
  }
}

async function applyLabels(context, result) {
  if (!context.repo || !context.prNumber || process.env.REVIEW_ROUTER_SKIP_LABELS === "1" || process.env.REVIEW_ROUTER_WRITE_OUTPUT !== "true") return;
  const labels = unique([
    result.attention,
    ...result.changedHotZones,
    ...result.signalHotZones,
  ]);

  for (const label of [...attentionLabels, "hot-zone:api", "hot-zone:harness", "hot-zone:package", "hot-zone:docs"]) {
    await deleteLabel(context.repo, context.prNumber, label);
  }
  try {
    for (const label of labels) {
      await ensureLabel(context.repo, label);
    }
    if (labels.length > 0) {
      await requestJson(`/repos/${context.repo}/issues/${context.prNumber}/labels`, {
        method: "POST",
        body: { labels },
      });
    }
  } catch (error) {
    console.warn(`[warning] could not update labels: ${error.message}`);
  }
}

function buildSummary(result) {
  const lines = [
    routerSummaryMarker,
    "## Review attention router",
    "",
    `- Result: \`${result.attention}\``,
    `- Highest severity: \`${result.highestSeverity}\``,
    `- Changed hot zones: ${result.changedHotZones.map((item) => `\`${item}\``).join(", ") || "none"}`,
    `- Signal hot zones: ${result.signalHotZones.map((item) => `\`${item}\``).join(", ") || "none"}`,
    `- Review signals: ${result.signals.length}`,
  ];
  for (const signal of result.signals.slice(0, 20)) {
    lines.push(`  - \`${signal.severity}\` ${signal.source}${signal.path ? `: \`${signal.path}\`` : ""}`);
  }
  return `${lines.join("\n")}\n`;
}

function writeStepSummary(result) {
  const path = process.env.GITHUB_STEP_SUMMARY;
  if (!path) return;
  try {
    fs.appendFileSync(path, buildSummary(result));
  } catch (error) {
    console.warn(`[warning] could not write step summary: ${error.message}`);
  }
}

async function postSummaryComment(context, result) {
  if (!context.repo || !context.prNumber || process.env.REVIEW_ROUTER_SKIP_COMMENT === "1" || process.env.REVIEW_ROUTER_WRITE_OUTPUT !== "true") return;
  const body = buildSummary(result);
  const existing = context.issueComments.find((comment) => {
    return isRouterSummaryComment(comment);
  });

  try {
    if (existing) {
      await requestJson(`/repos/${context.repo}/issues/comments/${existing.id}`, {
        method: "PATCH",
        body: { body },
      });
    } else {
      await requestJson(`/repos/${context.repo}/issues/${context.prNumber}/comments`, {
        method: "POST",
        body: { body },
      });
    }
  } catch (error) {
    console.warn(`[warning] could not write summary comment: ${error.message}`);
  }
}

async function loadContext() {
  const localFiles = parseLocalChangedFiles();
  if (localFiles) {
    return {
      files: localFiles,
      reviews: parseJsonEnv("REVIEW_ROUTER_REVIEWS_JSON"),
      reviewComments: parseJsonEnv("REVIEW_ROUTER_REVIEW_COMMENTS_JSON"),
      issueComments: parseJsonEnv("REVIEW_ROUTER_COMMENTS_JSON"),
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
  const reviews = await fetchPaged(`/repos/${repo}/pulls/${prNumber}/reviews`);
  let reviewComments;
  try {
    reviewComments = await fetchActiveReviewThreadComments(repo, prNumber);
  } catch (error) {
    console.warn(`[warning] could not fetch active review threads, falling back to REST comments: ${error.message}`);
    reviewComments = annotateReviewCommentStates(
      await fetchPaged(`/repos/${repo}/pulls/${prNumber}/comments`),
      reviews
    );
  }
  return {
    repo,
    prNumber,
    files: (await fetchPaged(`/repos/${repo}/pulls/${prNumber}/files`)).map((file) => file.filename),
    reviews,
    reviewComments,
    issueComments: await fetchPaged(`/repos/${repo}/issues/${prNumber}/comments`),
  };
}

function printSummary(result) {
  console.log(`review-attention-router result: ${result.attention}`);
  console.log(`highest-severity: ${result.highestSeverity}`);
  console.log(`changed-hot-zones: ${result.changedHotZones.join(", ") || "none"}`);
  console.log(`signal-hot-zones: ${result.signalHotZones.join(", ") || "none"}`);
  console.log(`review-signals: ${result.signals.length}`);
  for (const signal of result.signals.slice(0, 20)) {
    console.log(`- ${signal.severity} ${signal.source}${signal.path ? ` ${signal.path}` : ""}`);
  }
}

async function main() {
  const context = await loadContext();
  if (!context) {
    console.log("review-attention-router not required: no pull request context");
    return;
  }

  const result = classify(context);
  printSummary(result);
  writeStepSummary(result);
  await applyLabels(context, result);
  await postSummaryComment(context, result);
}

main().catch((error) => {
  console.warn(`[warning] review-attention-router failed non-fatally: ${error.message}`);
  process.exit(0);
});
NODE
