# steel-ledger-infra
Held together by thoughts, prayers, and point ties

# architecture
```mermaid
graph TD
    iOS[iOS App - SwiftUI] -->|REST| API[Vapor API]
    Web[Web App - React] -->|REST| API
    API --> DB[(Postgres - RDS)]
    API --> S3[S3 - Equipment/Kit Photos]
    API --> Secrets[Secrets Manager]
    API -->|hosted on| AppRunner[App Runner]
    CloudFront[CloudFront] --> S3
    CloudFront --> Web
```