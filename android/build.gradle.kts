buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15") // Google services plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Clean task to delete build directory
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
