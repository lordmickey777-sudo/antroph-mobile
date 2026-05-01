signingConfigs {
    create("release") {
        val storePath = System.getenv("CM_KEYSTORE_PATH")
            ?: throw GradleException("CM_KEYSTORE_PATH not set")

        val storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            ?: throw GradleException("CM_KEYSTORE_PASSWORD not set")

        val keyAlias = System.getenv("CM_KEY_ALIAS")
            ?: throw GradleException("CM_KEY_ALIAS not set")

        val keyPassword = System.getenv("CM_KEY_PASSWORD")
            ?: throw GradleException("CM_KEY_PASSWORD not set")

        storeFile = file(storePath)
        this.storePassword = storePassword
        this.keyAlias = keyAlias
        this.keyPassword = keyPassword

        println("✅ Using Codemagic keystore at: $storePath")
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
