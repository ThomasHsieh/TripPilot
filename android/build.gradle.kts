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

// 部分外掛（如 file_picker）仍以舊 compileSdk 編譯，但其相依
// flutter_plugin_android_lifecycle 要求 >= 36。於各子專案評估後強制 compileSdk 36。
subprojects {
    fun forceCompileSdk() {
        val ext = extensions.findByName("android")
            as? com.android.build.gradle.BaseExtension
        ext?.compileSdkVersion(36)
    }
    if (state.executed) {
        forceCompileSdk()
    } else {
        afterEvaluate { forceCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
