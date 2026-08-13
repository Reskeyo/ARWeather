// Top-level build.gradle.kts — repositories are declared in settings.gradle.kts
// for Flutter 3.22+ compatibility (allprojects block is deprecated).

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
