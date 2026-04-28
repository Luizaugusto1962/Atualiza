#!/usr/bin/env bash
#
# SISTEMA SAV - Script de Atualizacao Modular
# lembrete.sh - Modulo de Lembretes e Notas
# Padroes e regras de desenvolvimento: ver AGENTS.md
# Versao: 02/04/2026-00
# Autor: Luiz Augusto
#
#---------- FUNcoES DE LEMBRETES ----------#
# Variaveis globais esperadas
cfg_dir="${cfg_dir:-}"          # Caminho do diretorio de configuracao do programa.

# Mostra menu de lembretes
# Escreve nova nota
_escrever_nova_nota() {
    _limpa_tela
    _linha
    _mensagec "${YELLOW}" "Digite sua nota (pressione Ctrl+D para finalizar):"
    _linha

    local arquivo_notas="${cfg_dir}/lembrete"
    local tamanho_antes=0
    local tamanho_depois=0

    # Capturar tamanho atual do arquivo
    if [[ -f "$arquivo_notas" ]]; then
        tamanho_antes=$(wc -c < "$arquivo_notas")
    fi

    if cat >> "$arquivo_notas"; then
        # Verificar se algo foi realmente escrito
        tamanho_depois=$(wc -c < "$arquivo_notas")

        if [[ "$tamanho_depois" -gt "$tamanho_antes" ]]; then
            _linha
            _mensagec "${GREEN}" "Nota gravada com sucesso!"
        else
            _linha
            _mensagec "${YELLOW}" "Nenhum conteudo foi digitado."
        fi
        _read_sleep 2
    else
        _mensagec "${RED}" "Erro ao gravar nota"
        _read_sleep 2
    fi
}

# Mostra notas iniciais se existirem
_mostrar_notas_iniciais() {
    local nota_inicial="${cfg_dir}/lembrete"
    
    if [[ -f "$nota_inicial" && -s "$nota_inicial" ]]; then
        _visualizar_notas_arquivo "$nota_inicial"
    fi
}

# ---------- MENSAGEM DE ENTRADA ----------
# Gera ou edita a mensagem que sera exibida ao iniciar o programa
_gerar_aviso_entrada() {
    _limpa_tela
    _linha
    _mensagec "${YELLOW}" "Digite a mensagem de entrada (Ctrl+D para finalizar):"
    _linha

    local arquivo_msg="${cfg_dir}/avisos"
    local arquivo_tmp="${cfg_dir}/.avisos.tmp"

    # Gravar em arquivo temporario primeiro
    if cat > "$arquivo_tmp"; then
        if [[ -s "$arquivo_tmp" ]]; then
            mv -f "$arquivo_tmp" "$arquivo_msg"
            _linha
            _mensagec "${GREEN}" "Mensagem gravada com sucesso!"
        else
            rm -f "$arquivo_tmp"
            _linha
            _mensagec "${YELLOW}" "Nenhum conteudo foi digitado. Mensagem nao alterada."
        fi
        _read_sleep 2
    else
        rm -f "$arquivo_tmp"
        _mensagec "${RED}" "Erro ao gravar mensagem"
        _read_sleep 2
    fi
}

# Edita nota existente
_editar_aviso_existente() {
    local arquivo_avisos="${cfg_dir}/avisos"
    
    _limpa_tela
    if [[ -f "$arquivo_avisos" ]]; then
        if ! ${EDITOR:-nano} "$arquivo_avisos"; then
            _mensagec "${RED}" "Erro ao abrir editor!"
            _read_sleep 2
        fi
    else
        _mensagec "${YELLOW}" "Nenhuma mensagem de aviso encontrada para editar!"
        _read_sleep 2
    fi
}

# Exibe a mensagem de entrada e oferece opcao para excluir apos leitura
_mostrar_aviso() {
    local arquivo_msg="${cfg_dir}/avisos"
    if [[ -f "$arquivo_msg" ]] && grep -q '[^[:space:]]' "$arquivo_msg"; then
        _limpa_tela
        _linha "=" "${CYAN}"
        _mensagec "${YELLOW}" "MENSAGEM DE ENTRADA"
        _linha "=" "${CYAN}"
        printf "\n"
        # exibicao simples, respeitando largura do terminal
        local cols
        cols=$(tput cols 2>/dev/null || echo 80)
        fold -s -w "$cols" < "$arquivo_msg"
        printf "\n"
        _linha
        if _confirmar "Excluir mensagem de entrada?" "N"; then
            rm -f "$arquivo_msg"
            _mensagec "${GREEN}" "Mensagem removida"
            _read_sleep 1
        fi
    fi
}

# Apaga um arquivo de configuracao apos confirmacao
# Parametros: $1=caminho_arquivo $2=descricao (ex: "mensagem de entrada", "notas")
_apagar_arquivo_cfg() {
    local arquivo="$1"
    local descricao="$2"

    if [[ ! -f "$arquivo" ]]; then
        _mensagec "${YELLOW}" "Nenhuma ${descricao} encontrada para excluir!"
        _read_sleep 2
        return
    fi

    if _confirmar "Tem certeza que deseja apagar ${descricao}?" "N"; then
        if rm -f "$arquivo"; then
            _mensagec "${RED}" "${descricao^} excluida com sucesso!"
        else
            _mensagec "${RED}" "Erro ao excluir ${descricao}"
        fi
        _read_sleep 2
    fi
}

# Apaga manualmente a mensagem de entrada
_apagar_aviso_entrada() {
    _apagar_arquivo_cfg "${cfg_dir}/avisos" "mensagem de entrada"
}

# Apaga nota existente
_apagar_nota_existente() {
    _apagar_arquivo_cfg "${cfg_dir}/lembrete" "todas as notas"
}
# Parametros: $1=arquivo_de_notas
_visualizar_notas_arquivo() {
    local arquivo="$1"
    local llinha

    # Largura dinamica do terminal (fallback 80)
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # Ajuste para o prefixo "* - " e identacao
    local largura
    largura=$(( cols - 6 ))
    [[ $largura -lt 40 ]] && largura=40

    if [[ ! -f "$arquivo" || ! -r "$arquivo" ]]; then
        _mensagec "${RED}" "Arquivo de notas nao encontrado ou ilegivel: $arquivo"
        _press
        return 1
    fi

    _limpa_tela
    _linha "=" "${CYAN}"
    _mensagec "${YELLOW}" "LEMBRETES E NOTAS"
    _linha "=" "${CYAN}"
    printf "\n"

    while IFS= read -r llinha || [[ -n "$llinha" ]]; do
        # Ignora linhas vazias ou apenas com espacos
        [[ -z "${llinha//[[:space:]]/}" ]] && continue

        echo "$llinha" | fold -s -w "$largura" | {
            read -r primeira
            printf "* - %s\n" "$primeira"

            while IFS= read -r resto; do
                printf "    %s\n" "$resto"
            done
        }
    done < "$arquivo"

    printf "\n"
    _linha
    _press
}

# Edita nota existente
_editar_nota_existente() {
    local arquivo_notas="${cfg_dir}/lembrete"
    
    _limpa_tela
    if [[ -f "$arquivo_notas" ]]; then
        if ! ${EDITOR:-nano} "$arquivo_notas"; then
            _mensagec "${RED}" "Erro ao abrir editor!"
            _read_sleep 2
        fi
    else
        _mensagec "${YELLOW}" "Nenhuma nota encontrada para editar!"
        _read_sleep 2
    fi
}
