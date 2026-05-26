#!/bin/bash

# Definição de Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # Sem Cor

# Cabeçalho Raztechs Unlocker
echo -e "${GREEN}${BOLD}"
echo ' ____      _    _____ _____ _____ ____ _   _ ____  '
echo '|  _ \    / \  |__  /|_   _| ____/ ___| | | / ___| '
echo '| |_) |  / _ \   / /   | | |  _|| |   | |_| \___ \ '
echo '|  _ <  / ___ \ / /_   | | | |__| |___|  _  |___) |'
echo '|_| \_\/_/   \_\____|  |_| |_____\____|_| |_|____/ '
echo ' _   _ _   _ _     ___   ____ _  _______ ____      '
echo '| | | | \ | | |   / _ \ / ___| |/ / ____|  _ \     '
echo '| | | |  \| | |  | | | | |   | '\'' /|  _| | |_) |    '
echo '| |_| | |\  | |__| |_| | |___| . \| |___|  _ <     '
echo ' \___/|_| \_|_____\___/ \____|_|\_\_____|_| \_\    '
echo '                                                   '
echo '             --- CHATWOOT ---                      '
echo -e "${NC}"

# Função corrigida para não poluir as variáveis com textos de UI
select_container() {
    local search_term=$1
    local title=$2
    local result_var=$3
    
    echo -e "${YELLOW}Buscando containers contendo '${search_term}'...${NC}"
    
    mapfile -t containers < <(docker ps --format "{{.Names}}   |   📦 Imagem: {{.Image}}   |   ⏱️ Status: {{.Status}}" | grep -i "$search_term")
    
    if [ ${#containers[@]} -eq 0 ]; then
        echo -e "${RED}Erro: Nenhum container encontrado para '$search_term'.${NC}"
        echo "Verifique se a stack está rodando."
        exit 1
    fi

    echo -e "\n${GREEN}Selecione o $title:${NC}"
    
    PS3="Digite o número correspondente: "
    select opt in "${containers[@]}"; do
        if [[ -n "$opt" ]]; then
            # Extrai o nome limpo e remove qualquer quebra de linha ou caractere invisível
            local clean_name=$(echo "$opt" | awk '{print $1}' | tr -d '\r\n\t ')
            # Atribui diretamente à variável do sistema
            printf -v "$result_var" "%s" "$clean_name"
            return
        else
            echo -e "${RED}Opção inválida. Tente novamente.${NC}"
        fi
    done
}

# 1. Mapeamento interativo dos containers
select_container "postgres" "Container do PostgreSQL" POSTGRES_CONTAINER
echo -e "✅ Selecionado: ${GREEN}$POSTGRES_CONTAINER${NC}\n"

select_container "chatwoot" "Container Principal do Chatwoot (App)" CHATWOOT_CONTAINER
echo -e "✅ Selecionado: ${GREEN}$CHATWOOT_CONTAINER${NC}\n"

# 2. Configurações Dinâmicas
echo -e "${CYAN}=== Configurações de Banco de Dados ===${NC}"
read -p "Usuário do banco de dados [Padrão: postgres]: " DB_USER
DB_USER=${DB_USER:-postgres}

read -p "Nome do banco de dados [Padrão: chatwoot]: " DB_NAME
DB_NAME=${DB_NAME:-chatwoot}

# Resumo da Operação
echo -e "\n${BLUE}--- Resumo da Operação ---${NC}"
echo -e "Container DB:  ${BOLD}$POSTGRES_CONTAINER${NC}"
echo -e "Container App: ${BOLD}$CHATWOOT_CONTAINER${NC}"
echo -e "Usuário DB:    ${BOLD}$DB_USER${NC}"
echo -e "Nome DB:       ${BOLD}$DB_NAME${NC}"
echo -e "${BLUE}--------------------------${NC}\n"

read -p "Tudo correto? Deseja prosseguir com a injeção via Raztechs unlocker? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Operação cancelada pelo usuário.${NC}"
    exit 1
fi

set +H

# 3. Execução das Queries SQL
echo -e "\n${CYAN}[1/4] Atualizando plano para Enterprise...${NC}"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "UPDATE public.installation_configs SET serialized_value = '\"--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: enterprise\n\"' WHERE name = 'INSTALLATION_PRICING_PLAN';" > /dev/null

echo -e "\n${CYAN}[2/4] Atualizando cota de usuários para 10.000...${NC}"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "UPDATE public.installation_configs SET serialized_value = '\"--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvalue: 10000\n\"' WHERE name = 'INSTALLATION_PRICING_PLAN_QUANTITY';" > /dev/null

# 4. Injeção do Script Ruby
echo -e "\n${CYAN}[3/4] Aplicando trigger de proteção permanente no PostgreSQL...${NC}"
docker exec -i "$CHATWOOT_CONTAINER" sh -c "wget -qO-  https://raw.githubusercontent.com/raikovisk/Dchat-unlock/refs/heads/main/unlock_permanent.rb | bundle exec rails runner -" > /dev/null

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   Ativação no banco e bloqueios aplicados com sucesso!   ${NC}"
echo -e "${GREEN}======================================================${NC}\n"

# 5. Restart da Stack e Confirmação
echo -e "${YELLOW}Para que o Chatwoot reconheça o plano Enterprise e aplique os fallbacks, é necessário reiniciar o container do Chatwoot.${NC}"
read -p "Deseja reiniciar a stack do Chatwoot agora? (s/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}[4/4] Reiniciando container do Chatwoot...${NC}"
    docker restart "$CHATWOOT_CONTAINER" > /dev/null
    echo -e "\n${GREEN}🚀 Stack reiniciada com sucesso!${NC}"
else
    echo -e "\n${YELLOW}⚠️ Restart ignorado. Lembre-se de reiniciar manualmente para ter efeito.${NC}"
fi

# 6. Verificação de Status Final
echo -e "\n${CYAN}=== Verificando Status Final da Ativação ===${NC}"
STATUS_PLAN=$(docker exec -i "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT serialized_value FROM public.installation_configs WHERE name = 'INSTALLATION_PRICING_PLAN';" | grep -o 'enterprise' || echo "N/A")

STATUS_QTD=$(docker exec -i "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT serialized_value FROM public.installation_configs WHERE name = 'INSTALLATION_PRICING_PLAN_QUANTITY';" | grep -o -E '[0-9]+' | head -n 1 || echo "N/A")

echo -e "📌 Plano Atual:          ${GREEN}${BOLD}${STATUS_PLAN^^}${NC}"
echo -e "📌 Limite de Usuários:   ${GREEN}${BOLD}${STATUS_QTD}${NC}"

if [[ "$STATUS_PLAN" == "enterprise" ]]; then
    echo -e "\n🎉 ${GREEN}Tudo pronto! O Raztechs unlocker concluiu o processo. O Chatwoot agora possui os recursos Enterprise ativos.${NC}"
else
    echo -e "\n⚠️ ${RED}Atenção: Não foi possível confirmar a ativação automaticamente. Verifique os logs do PostgreSQL.${NC}"
fi
echo ""
