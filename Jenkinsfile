pipeline {
    agent {
        label "guixsd"
    }
    stages {
        stage("Invoking emacs") {
            steps {
                sh "emacs --quick --batch --script ./export.el"
            }
        }
   }
    post {
        always {
            sendNotifications currentBuild.result
        }
    }
}
