// The Linux stages of CI for Jenkins: lint, test every package, ride a
// workout on the virtual trainer. The macOS and simulator stages need a
// macOS agent with Xcode; GitHub Actions runs them (.github/workflows/ci.yml).
pipeline {
    agent {
        docker { image 'swift:6.3-noble' }
    }
    environment {
        CI = 'true'
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    stages {
        stage('Toolchain') {
            steps { sh 'swift --version' }
        }
        stage('Lint') {
            steps { sh 'tools/dev.sh lint' }
        }
        stage('Test') {
            steps { sh 'tools/dev.sh test' }
        }
        stage('Ride a workout') {
            steps { sh 'tools/dev.sh run sim spinline-sim --workout Content/Workouts/openers.json --every 60' }
        }
    }
}
