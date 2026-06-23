import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.kotlin.dsl.getByType

internal fun Project.versionInt(alias: String): Int {
    return extensions
        .getByType<VersionCatalogsExtension>()
        .named("libs")
        .findVersion(alias)
        .orElseThrow { IllegalArgumentException("Missing version catalog entry: $alias") }
        .requiredVersion
        .toInt()
}
