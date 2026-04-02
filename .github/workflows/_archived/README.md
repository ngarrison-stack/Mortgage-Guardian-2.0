# Archived Workflows

## complete-ci-cd.yml

Archived on 2026-04-02. This workflow was non-functional and aspirational -- it referenced unconfigured services (SonarCloud, Snyk, FOSSA, Codecov, Docker Hub, Kubernetes, OWASP ZAP, PCI DSS scanner, HIPAA checker, Microsoft Teams) and infrastructure (k8s manifests, staging/production environments) that do not exist in this repository. It also used deprecated action versions (@v3, @v2).

Replaced by focused, working workflows:
- `backend-ci.yml` -- Backend lint and test
