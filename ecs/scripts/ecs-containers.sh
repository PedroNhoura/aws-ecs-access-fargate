# Esse Script acessa o container pelo AWS Exec, ele usa o comando aws ecs execute-command para executar o comando no container.
# Dentro da Task ele irá ler o primeiro container disponível e acessá-lo.


#!/bin/bash

# Configurações iniciais
AWS_REGION="us-east-1"

# Função para capturar entrada e validar
get_input() {
    local prompt="$1"
    local input=""
    while [ -z "$input" ]; do
        read -e -p "$prompt" input
        if [ -z "$input" ]; then
            echo "⚠️ Entrada inválida. Por favor, tente novamente."
        fi
    done
    echo "$input"
}

# Solicita ao usuário os nomes do Cluster e do Serviço
echo "ℹ️ Por favor, insira os nomes do Cluster e do Serviço que deseja usar."
ECS_CLUSTER=$(get_input "Digite o nome do Cluster ECS: ")
echo "✔️ Nome do Cluster armazenado: $ECS_CLUSTER"
echo ""

SERVICE=$(get_input "Digite o nome do Serviço ECS: ")
echo "✔️ Nome do Serviço armazenado: $SERVICE"
echo ""

# Configura a região da AWS
echo "🌎 Configurando a região da AWS para $AWS_REGION..."
aws configure set region $AWS_REGION
if [ $? -eq 0 ]; then
    echo "✅ Região da AWS configurada com sucesso."
else
    echo "❌ Falha ao configurar a região da AWS. Verifique se o AWS CLI está instalado e configurado corretamente."
    exit 1
fi

# Verifica se o Cluster existe
echo "🔍 Verificando se o Cluster '$ECS_CLUSTER' existe..."
CLUSTER_EXISTS=$(aws ecs describe-clusters --clusters "$ECS_CLUSTER" --region $AWS_REGION --query "clusters[?clusterName=='$ECS_CLUSTER'] | length(@)" --output text)
if [ "$CLUSTER_EXISTS" -eq 0 ]; then
    echo "❌ O Cluster '$ECS_CLUSTER' não existe ou não está ativo. Verifique o nome e tente novamente."
    exit 1
fi
echo "✅ Cluster '$ECS_CLUSTER' verificado com sucesso."

# Verifica se o Serviço existe no Cluster
echo "🔍 Verificando se o Serviço '$SERVICE' existe no Cluster '$ECS_CLUSTER'..."
SERVICE_EXISTS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$SERVICE" --region $AWS_REGION --query "services[?serviceName=='$SERVICE'] | length(@)" --output text)
if [ "$SERVICE_EXISTS" -eq 0 ]; then
    echo "❌ O Serviço '$SERVICE' não existe no Cluster '$ECS_CLUSTER'. Verifique o nome e tente novamente."
    exit 1
fi
echo "✅ Serviço '$SERVICE' verificado com sucesso."

# Obtém o ID da primeira task RUNNING associada ao serviço
echo "🔍 Obtendo o ID da primeira task RUNNING no serviço $SERVICE..."
TASK_ID=$(aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $SERVICE --region $AWS_REGION --query "taskArns[0]" --output text)

# Verifica se foi possível obter o ID da task
if [ -z "$TASK_ID" ] || [ "$TASK_ID" == "None" ]; then
    echo "❌ Nenhuma task encontrada no serviço $SERVICE. Verifique se o serviço está em execução."
    exit 1
fi

echo "✅ ID da Task obtido automaticamente: $TASK_ID"

# Obtém os detalhes da task
echo "🔍 Obtendo informações da task $TASK_ID..."
TASK_DETAILS=$(aws ecs describe-tasks --cluster $ECS_CLUSTER --tasks $TASK_ID --region $AWS_REGION --query "tasks[0]" --output json)
if [ $? -ne 0 ]; then
    echo "❌ Falha ao obter informações da task. Verifique o ID da task e tente novamente."
    exit 1
fi

# Lista containers na task
echo "📝 Containers na Task $TASK_ID:"
CONTAINERS=$(echo "$TASK_DETAILS" | jq -r '.containers[] | {Name: .name, Status: .lastStatus, RuntimeId: .runtimeId, ExitCode: .exitCode}')
if [ -z "$CONTAINERS" ]; then
    echo "❌ Nenhum container encontrado na task. Verifique se a task está em execução."
    exit 1
fi

# Exibe informações de cada container
echo "$CONTAINERS" | jq -r '"\n📦 Container Name: \(.Name)\n   Status: \(.Status)\n   Runtime ID: \(.RuntimeId)\n   Exit Code: \(.ExitCode // "N/A")\n"'

# Obtém o nome do primeiro container listado
FIRST_CONTAINER=$(echo "$TASK_DETAILS" | jq -r '.containers[0].name')
if [ -z "$FIRST_CONTAINER" ]; then
    echo "❌ Falha ao identificar o primeiro container. Verifique a task."
    exit 1
fi

# Conecta ao container usando /bin/sh
echo "🔗 Conectando ao container $FIRST_CONTAINER usando /bin/sh..."
aws ecs execute-command \
    --cluster $ECS_CLUSTER \
    --task $TASK_ID \
    --container $FIRST_CONTAINER \
    --region $AWS_REGION \
    --command "/bin/sh" \
    --interactive

if [ $? -eq 0 ]; then
    echo "✅ Conexão finalizada com sucesso com o container $FIRST_CONTAINER."
else
    echo "❌ Falha ao conectar ao container $FIRST_CONTAINER. Verifique os logs para mais detalhes."
    exit 1
fi
