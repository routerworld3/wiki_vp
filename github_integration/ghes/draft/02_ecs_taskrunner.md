

The main components are:

* **Cluster** — Logical grouping of where your containers run. A cluster can use **EC2 capacity** or **Fargate**.
* **Task Definition** — The container blueprint. It defines the image, CPU/memory, ports, environment variables, IAM roles, logging, volumes, and networking.
* **Task** — A running instance of a task definition. If the task definition is the blueprint, a task is the actual running container workload.
* **Service** — Keeps a desired number of tasks running continuously. For example, `desiredCount = 3` means ECS tries to maintain three healthy tasks.
* **Container** — The actual Docker container inside a task. A task can contain one or multiple containers.
* **Capacity Provider** — Tells ECS where to get compute capacity, such as Fargate, Fargate Spot, or an EC2 Auto Scaling Group.
* **ECS Agent** — Runs on EC2-based ECS container instances and communicates with the ECS control plane. You generally don't manage this with Fargate.
* **Container Instance** — An EC2 instance registered to an ECS cluster. This exists only when using ECS on EC2.
* **ENI / `awsvpc` networking** — Common networking mode where each task gets its own private IP and security groups.
* **Load Balancer / Target Group** — Optional. ALB or NLB can send traffic to ECS tasks.
* **Task IAM Role** — Permissions used by the application running inside the container, such as access to S3 or Secrets Manager.
* **Task Execution Role** — Permissions ECS itself needs to start the task, such as pulling an image from ECR or fetching secrets.
* **ECR** — Usually where the Docker image is stored.
* **CloudWatch Logs** — Common destination for container stdout/stderr logs.

For your **GitHub runner on ECS**, it probably looks like this:

```text
ECS Cluster
   |
   +-- ECS Service
          |
          +-- Task
               |
               +-- GitHub Runner Container
               |
               +-- Task ENI
                    Private IP: 10.x.x.x
```

The runner container then makes an **outbound HTTPS connection** to GHES:

```text
Runner Container
      |
      | HTTPS :443
      v
Task ENI / Private IP
      |
      v
VPC Routing / DNS
      |
      +----> ALB ----> GHES

        OR

      +-------------> GHES directly
```

That **Task ENI/private IP** is especially important for the troubleshooting we were discussing, because you can use it in VPC Flow Logs to determine whether the ECS runner is going to the ALB or directly to the GHES instance.
