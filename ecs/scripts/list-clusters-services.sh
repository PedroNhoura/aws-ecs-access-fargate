#!/bin/bash

# Defina a região onde você quer listar os clusters e serviços
REGIAO="us-east-1"  # Alterar para a região desejada (exemplo: us-east-1, eu-west-1)

# Nome do arquivo de saída onde as informações serão salvas
RESULTADO="/home/pmoura/scrips-uteis/clusters_e_servicos.json"

# Cria o arquivo JSON vazio para armazenar os dados
echo "{" > $RESULTADO
echo "  \"clusters\": [" >> $RESULTADO

# Liste todos os clusters na região especificada
CLUSTERS=$(aws ecs list-clusters --region $REGIAO --query 'clusterArns' --output text)

# Itera sobre cada cluster e obtém os serviços associados
for CLUSTER in $CLUSTERS; do
    # Extrai o nome do cluster a partir do ARN (padrão: arn:aws:ecs:<regiao>:<account_id>:cluster/<cluster_name>)
    CLUSTER_NAME=$(echo $CLUSTER | awk -F'/' '{print $2}')
    
    # Liste os serviços dentro do cluster
    SERVICOS=$(aws ecs list-services --cluster $CLUSTER --region $REGIAO --query 'serviceArns' --output text)

    # Adiciona o cluster e seus serviços no arquivo JSON
    echo "    {" >> $RESULTADO
    echo "      \"cluster\": \"$CLUSTER_NAME\"," >> $RESULTADO
    echo "      \"services\": [" >> $RESULTADO

    # Para cada serviço listado no cluster, adicione ao JSON
    for SERVICE in $SERVICOS; do
        SERVICE_NAME=$(echo $SERVICE | awk -F'/' '{print $2}')
        echo "        \"$SERVICE_NAME\"," >> $RESULTADO
    done

    # Remove a última vírgula do bloco de serviços (corrige a sintaxe JSON)
    sed -i '$ s/,$//' $RESULTADO

    # Fecha a lista de serviços e o cluster
    echo "      ]" >> $RESULTADO
    echo "    }," >> $RESULTADO
done

# Remove a última vírgula (corrige a sintaxe JSON para ficar válido)
sed -i '$ s/,$//' $RESULTADO

# Fecha o JSON
echo "  ]" >> $RESULTADO
echo "}" >> $RESULTADO

# Confirma a criação do arquivo JSON
echo "Resultado salvo em $RESULTADO"
