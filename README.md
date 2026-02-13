# 04_App_CICD_Monitoring

This directory contains Ansible playbooks and configurations for deploying the CI/CD pipeline, monitoring stack, and application dependencies.

## Directory Structure

```
04_App_CICD_Monitoring/
├── ansible.cfg             # Ansible configuration
├── inventory.ini           # Inventory file
├── site.yml                # Main entry point playbook
├── requirements.yml        # Galaxy requirements
├── playbooks/              # Organized playbooks
│   ├── deploy/             # Deployment playbooks (CICD, Monitoring, ArgoCD, Registry)
│   ├── configure/          # Configuration playbooks (Jenkins SSH, Harbor Replication)
│   ├── migration/          # Migration playbooks (GitHub to Gitea)
│   └── tasks/              # Reusable tasks (sub-playbooks)
├── roles/                  # Ansible roles
└── k8s_manifests/          # Kubernetes manifests
```

## Usage

To run the entire suite:

```bash
ansible-playbook site.yml
```

To run specific components, execute the playbooks in `playbooks/deploy/` or `playbooks/configure/`.
