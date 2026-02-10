pipeline {
    agent any

    parameters {
        choice(name: 'PLAYBOOK', choices: ['site.yml', 'playbooks/deploy/cicd.yml', 'playbooks/configure/jenkins_ssh.yml', 'playbooks/deploy/registry.yml', 'playbooks/deploy/monitoring.yml', 'playbooks/deploy/argocd.yml', 'playbooks/deploy/app_dependencies.yml', 'playbooks/deploy/argocd_apps.yml', 'playbooks/configure/configure_waf.yml', 'playbooks/configure/harbor_replication.yml', 'playbooks/migration/github_to_gitea.yml'], description: 'Select the App/CICD playbook to run')
        string(name: 'LIMIT', defaultValue: 'all', description: 'Target hosts limit (e.g. PC5). Default: all')
        booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Run in check mode (dry-run)?')
    }

    environment {
        ANSIBLE_FORCE_COLOR = 'true'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('SSH Auto-Heal (Distribute Keys)') {
            steps {
                script {
                   echo '🚑 SSH 연결 자가 치유 (Self-Healing) 시작...'
                   sh 'chmod +x Script/jenkins_distribute_ssh_ansible.sh'
                   sh './Script/jenkins_distribute_ssh_ansible.sh'
                }
            }
        }

        stage('Pre-flight Check') {
            steps {
                script {
                   echo '🔍 Checking connectivity...'
                   sh 'ansible all -i inventory.ini -m ping -l "${LIMIT}"'
                }
            }
        }

        stage('Dry Run (Simulation)') {
            when {
                expression { return params.DRY_RUN == true }
            }
            steps {
                script {
                    echo "📦 Ansible 필수 모듈 설치 중..."
                    sh "ansible-galaxy collection install -r requirements.yml"
                    
                    echo "🔍 변경사항을 시뮬레이션 합니다 (Dry Run)..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\" --check"
                }
            }
        }

        stage('Human Approval') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    input message: "'${params.PLAYBOOK}'를 실제로 배포하시겠습니까?", ok: "🚀 배포 승인 (Deploy)"
                }
            }
        }

        stage('Deploy (Apply)') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    echo "🚀 실제 배포를 시작합니다..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\""
                }
            }
        }
    }
}
