# **AWS ECS Fargate Utilities**

Este repositório contém scripts e exemplos úteis para gerenciar e acessar containers no AWS ECS Fargate. Ele foi projetado para ajudar equipes que precisam realizar operações frequentes de reinicialização de tasks, habilitar o ECS Exec e acessar containers.

---

## **Pré-requisitos**

Para usar os scripts e comandos neste repositório, certifique-se de que os seguintes requisitos estão atendidos:

1. **AWS CLI**: Instalado e configurado. [Guia de instalação](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
2. **Session Manager Plugin**: Instalado para permitir o uso do `aws ecs execute-command`. [Guia de instalação](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-installation.html)
3. **Fargate Version**: Tasks devem estar na versão **1.4 ou superior**.
4. **Permissões IAM**: A role `ecsTaskExecutionRole` deve incluir a política JSON descrita abaixo:

```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Action": [
              "ssm:StartSession",
              "ssm:SendCommand",
              "ssm:ListCommandInvocations",
              "ssm:DescribeInstanceInformation",
              "ssm:TerminateSession",
              "ssm:GetParameter",
              "ssm:DescribeSessions",
              "ssm:ListDocuments",
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ecs:UpdateService",
              "ecs:DescribeServices",
              "ecs:ListTasks",
              "ecs:ListClusters",
              "ecs:ListServices",
              "ecs:DescribeTasks",
              "ecs:DescribeClusters",
              "ecs:StartTask",
              "ecs:StopTask",
              "ecs:ExecuteCommand"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": "iam:ListRoles",
          "Resource": "*"
      }
  ]
}


```

## **Scripts Disponíveis**

### **1. `ecs-renew-tasks.sh`**

Reinicia todas as tasks associadas a um serviço no ECS, habilitando o ECS Exec para acesso posterior aos containers.

#### **Como usar**

1. Torne o script executável:

```bash
chmod +x ecs-renew-tasks.sh
./ecs-renew-tasks.sh


```

### **2. `ecs-containers.sh`**

Lista os containers de uma task no ECS e permite acessar o primeiro container disponível.

#### **Como usar**

1. Torne o script executável:

```bash
chmod +x ecs-containers.sh
./ecs-containers.sh

```

## **Comandos Úteis**

### **Verificar o ECS Exec**

Use o comando abaixo para verificar se o `--enable-execute-command` está ativado:


```bash 
bash <(curl -Ls https://raw.githubusercontent.com/aws-containers/amazon-ecs-exec-checker/main/check-ecs-exec.sh) <NOME DO CLUSTER> <ID DA TASK>

### Renovar o Serviço


```bash
aws ecs update-service \
    --cluster <NOME_DO_CLUSTER> \
    --service <NOME_DO_SERVICO> \
    --region us-east-1 \
    --enable-execute-command \
    --force-new-deployment

### **Acessar Container**

```bash
aws ecs execute-command \
    --region us-east-1 \
    --cluster <NOME_DO_CLUSTER> \
    --task <ID_DA_TASK> \
    --container <NOME_DO_CONTAINER> \
    --command "/bin/sh" \
    --interactive

### **Listar e Descrever Tasks**

```bash
aws ecs list-tasks --cluster <NOME_DO_CLUSTER> --region us-east-1

### **Describe Completo**

```bash
aws ecs describe-tasks \
    --cluster <NOME_DO_CLUSTER> \
    --tasks $(aws ecs list-tasks --cluster <NOME_DO_CLUSTER> --region us-east-1 --query 'taskArns[*]' --output text) \
    --region us-east-1 \
    --query 'tasks[*].containers[*].{Name:name,Status:lastStatus,RuntimeId:runtimeId,Image:image}'