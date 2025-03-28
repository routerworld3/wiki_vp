### 🧩 **AppStream AppBlock Deployment Flow (ASCII Diagram)**

```text
                              ┌──────────────┐
                              │ 1st Pipeline │
                              │     Run      │
                              └──────┬───────┘
                                     │
                                     ▼
      ┌────────────────┐      ┌────────────────────┐      ┌─────────────┐
      │ AppBlock       │◄─────┤ AppBlock Builder    ├─────┤ Builder VPC │
      └─────┬──────────┘      └────────────────────┘      └─────────────┘
            │
      (AppBlock inactive)
            │
       ┌────▼────┐
       │ 1.1     │ Launch Builder Session
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.2     │ Install App in Builder
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.3     │ Stop Recording & Save VHD
       └────┬────┘
            ▼
       ┌────▼────┐
       │   S3    │ ←─── VHD Stored
       └────┬────┘
            ▼
       ┌────▼────┐
       │ 1.4     │ Update SSM Param with EXE Path
       └────┬────┘
            ▼
       ┌──────────────┐
       │ 2nd Pipeline │
       │     Run      │
       └──────┬───────┘
              ▼
       ┌────────────────┐
       │ Application     │
       │ (exe path, logo)│
       └──────┬──────────┘
              │
              ▼
       ┌────────────────┐
       │ CloudFormation │
       └──────┬──────────┘
              ▼
      ┌────────────────────┐
      │ Elastic Fleet      │
      │  (stream.std.med)  │
      └──────┬─────────────┘
             ▼
        ┌──────────────┐
        │    Stack     │
        └──────────────┘
             │
             ▼
       ┌──────────────┐
       │  Fleet VPC   │
       └──────────────┘
```
