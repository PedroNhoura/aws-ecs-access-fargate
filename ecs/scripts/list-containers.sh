#!/bin/bash

# Nome do arquivo JSON de saída
OUTPUT_FILE="/home/pmoura/scrips-uteis/tasks_containers.json"

# Inicializa o JSON
echo "{" > $OUTPUT_FILE
echo '  "clusters": {' >> $OUTPUT_FILE

# Coleta a lista de clusters
clusters=$(aws ecs list-clusters --query "clusterArns" --output text)
declare -A cluster_services

for cluster in $clusters; do
  # Extrai o nome do cluster
  cluster_name=$(basename "$cluster")
  echo "    \"$cluster_name\": {" >> $OUTPUT_FILE

  # Coleta a lista de serviços para o cluster
  services=$(aws ecs list-services --cluster "$cluster" --query "serviceArns" --output text)
  echo '      "services": {' >> $OUTPUT_FILE

  for service in $services; do
    # Extrai o nome do serviço
    service_name=$(basename "$service")
    echo "        \"$service_name\": {" >> $OUTPUT_FILE

    # Coleta a lista de tasks para o serviço
    tasks=$(aws ecs list-tasks --cluster "$cluster" --service-name "$service" --query "taskArns" --output text)
    echo '          "tasks": {' >> $OUTPUT_FILE

    for task in $tasks; do
      # Extrai o ID da task
      task_id=$(basename "$task")
      echo "            \"$task_id\": [" >> $OUTPUT_FILE

      # Coleta a lista de containers para a task
      containers=$(aws ecs describe-tasks --cluster "$cluster" --tasks "$task" --query "tasks[0].containers[].name" --output text)
      for container in $containers; do
        echo "              \"$container\"," >> $OUTPUT_FILE
      done

      # Remove a última vírgula e fecha o array de containers
      sed -i '$ s/,$//' $OUTPUT_FILE
      echo "            ]," >> $OUTPUT_FILE
    done

    # Remove a última vírgula e fecha o objeto de tasks
    sed -i '$ s/,$//' $OUTPUT_FILE
    echo "          }," >> $OUTPUT_FILE
  done

  # Remove a última vírgula e fecha o objeto de serviços
  sed -i '$ s/,$//' $OUTPUT_FILE
  echo "      }" >> $OUTPUT_FILE
  echo "    }," >> $OUTPUT_FILE
done

# Remove a última vírgula e fecha o JSON
sed -i '$ s/,$//' $OUTPUT_FILE
echo "  }" >> $OUTPUT_FILE
echo "}" >> $OUTPUT_FILE

# Indica que o script foi concluído
echo "Arquivo JSON gerado em $OUTPUT_FILE"
