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

# Atualiza o serviço e habilita o ECS Exec
echo "🔄 Atualizando o serviço e habilitando o ECS Exec..."
aws ecs update-service --cluster $ECS_CLUSTER --service $SERVICE --region $AWS_REGION --enable-execute-command --force-new-deployment > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Serviço atualizado com sucesso e ECS Exec habilitado. Aguardando novas tasks serem criadas..."
else
    echo "❌ Falha ao atualizar o serviço. Verifique os logs para mais detalhes."
    exit 1
fi

# Aguarda um tempo para que as novas tasks sejam criadas
echo "⏳ Aguardando a criação das novas tasks..."
sleep 20

# Verifica o estado das tasks
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "⏳ Verificando se todas as tasks estão no estado RUNNING (tentativa $((RETRY_COUNT + 1))/$MAX_RETRIES)..."

    # Obtem todas as tasks do serviço
    ALL_TASKS=$(aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $SERVICE --region $AWS_REGION --query "taskArns" --output text)
    ALL_RUNNING=true

    for TASK in $ALL_TASKS; do
        # Verifica se a task está no estado RUNNING
        TASK_STATUS=$(aws ecs describe-tasks --cluster $ECS_CLUSTER --tasks $TASK --region $AWS_REGION --query "tasks[0].lastStatus" --output text)
        if [ "$TASK_STATUS" != "RUNNING" ]; then
            ALL_RUNNING=false
            break
        fi
    done

    if [ "$ALL_RUNNING" = true ]; then
        echo "✅ Todas as tasks estão no estado RUNNING."
        break
    fi

    sleep 5
    ((RETRY_COUNT++))
done

# Se o número de tentativas atingiu o máximo e as tasks ainda não estão no estado RUNNING
if [ "$ALL_RUNNING" != true ]; then
    echo "❌ Tempo esgotado para detectar todas as tasks no estado RUNNING. Verifique o status do serviço manualmente."
    exit 1
fi

# Mensagem final
echo "✅ Todas as tasks do Cluster '$ECS_CLUSTER' no Serviço '$SERVICE' foram reiniciadas."
echo "✅ Agora o acesso aos containers do seu cluster pode ser realizado."
