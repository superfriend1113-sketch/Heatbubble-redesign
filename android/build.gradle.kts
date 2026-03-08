allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force compileSdk 36 on library subprojects (e.g. isar_flutter_libs).
// Skip :app because evaluationDependsOn already evaluated it.
subprojects {
    if (name != "app") {
        afterEvaluate {
            val androidExt = extensions.findByType(
                com.android.build.gradle.BaseExtension::class.java
            )
            androidExt?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
