pipeline {
    agent {
        label "master"
    }
    stages {
        stage("Invoking emacs") {
            steps {
                sh "emacs --batch --script ./export.el"
            }
        }
   }
    post {
        always {
            sendNotifications currentBuild.result
        }
    }
}
