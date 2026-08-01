expense-tracker-devops/
│
├── app/
│   └── backend/
│       ├── config/
│       ├── controllers/
│       ├── DB/
│       ├── middleware/
│       ├── models/
│       ├── Routers/
│       ├── utils/
│       ├── app.js
│       ├── package.json
│       ├── package-lock.json
│       ├── Dockerfile
│       └── .dockerignore
│
├── docker/
│   ├── backend/
│   └── mongodb/
│
├── kubernetes/
│   ├── deployments/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/
│   ├── ingress/
│   └── storage/
│
├── terraform/
│   ├── modules/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   └── README.md
│
├── jenkins/
│   ├── Jenkinsfile
│   ├── shared-library/
│   └── README.md
│
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
│
├── scripts/
│   ├── setup.sh
│   ├── cleanup.sh
│   └── healthcheck.sh
│
├── docs/
│   │
│   ├── README.md                       📖 DevOps Engineer's Handbook
│   ├── MENTOR-HANDOFF.md               🤝 Mentorship continuity
│   ├── 00-project-state.md             📍 Current project status
│   │
│   ├── Volume-1-Docker/
│   │   ├── 01-docker-fundamentals.md
│   │   ├── 02-docker-networking.md
│   │   ├── 03-docker-volumes.md
│   │   ├── 04-docker-healthchecks.md
│   │   └── reflection.md
│   │
│   ├── Volume-2-Continuous-Integration/
│   │   ├── 05-ci-fundamentals.md
│   │   ├── 06-jenkins-fundamentals.md
│   │   ├── 07-building-your-first-pipeline.md
│   │   ├── 08-pipeline-stages.md
│   │   ├── 09-building-docker-images.md
│   │   └── reflection.md
│   │
│   ├── Volume-3-Kubernetes/
│   │   ├── 10-kubernetes-fundamentals.md
│   │   ├── 11-pods.md
│   │   ├── 12-deployments.md
│   │   ├── 13-services.md
│   │   ├── 14-configmaps-and-secrets.md
│   │   ├── 15-storage.md
│   │   ├── 16-probes.md
│   │   └── reflection.md
│   │
│   ├── Volume-4-Monitoring/
│   │   ├── 17-prometheus.md
│   │   ├── 18-grafana.md
│   │   ├── 19-logging.md
│   │   ├── 20-alerting.md
│   │   └── reflection.md
│   │
│   ├── Volume-5-Terraform/
│   │   ├── 21-terraform-fundamentals.md
│   │   ├── 22-modules.md
│   │   ├── 23-state-management.md
│   │   ├── 24-aws-infrastructure.md
│   │   └── reflection.md
│   │
│   ├── architecture.md
│   ├── troubleshooting.md
│   ├── glossary.md
│   └── references.md
│
├── docker-compose.yml
├── .gitignore
├── LICENSE
└── README.md