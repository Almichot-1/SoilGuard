allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Work around a Windows path issue where some build steps treat spaces as path separators
// (e.g. "C:\Users\NOOR\ AL\ MUSABAH\...") which breaks builds when the workspace path
// contains spaces.
//
// If you prefer a different location, set SOIL_SENSE_BUILD_DIR to an absolute path.
val isWindows = System.getProperty("os.name").lowercase().contains("windows")
val workspaceHasSpaces = rootProject.projectDir.absolutePath.contains(' ')
val buildRoot =
    if (isWindows && workspaceHasSpaces) {
        val fromEnv = System.getenv("SOIL_SENSE_BUILD_DIR")?.takeIf { it.isNotBlank() }
        val dir = File(fromEnv ?: "C:/src/soil_sense_build")
        dir.mkdirs()
        dir
    } else {
        // Keep Flutter's default layout (workspace-relative) when paths are safe.
        rootProject.file("../../build")
    }

rootProject.buildDir = buildRoot

subprojects {
    project.buildDir = File(buildRoot, project.name)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
