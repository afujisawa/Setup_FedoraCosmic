#!/usr/bin/env bash
set -euo pipefail

OS_RELEASE=/etc/os-release

#Cores
AZUL=$'\e[1;34m'
VERDE=$'\e[1;32m'
AMARELO=$'\e[1;33m'
VERMELHO=$'\e[1;31m'
RESETAR=$'\e[0m'

mensagem(){
	case "$1" in
		"INFO") COR="$AZUL";;
		"SUCESSO") COR="$VERDE";;
		"ALERTA") COR="$AMARELO";;
		"ERRO") COR="$VERMELHO";;
		*) printf "%s[ERRO] Mensagem não identificada\n" "$VERMELHO"; exit 1;;
	esac

	printf "%s[%s]%s %s\n" "$COR" "$1" "$RESETAR" "$2."
}

verifica_distro(){
	if [[ -f "$OS_RELEASE" ]]; then
		# shellcheck disable=SC1090
		source "$OS_RELEASE"

		if [[ "$ID" == "fedora" ]]; then
			mensagem "SUCESSO" "Distribuição Fedora detectada"
		else
			mensagem "ERRO" "Script exclusivo para distribuição Fedora"
		fi
	else
		mensagem "ERRO" "Não foi possível identificar a distribuição"
		mensagem "INFO" "Arquivo $OS_RELEASE não encontrado"
		exit 1
	fi
}

verifica_internet(){
if ping -c 1 8.8.8.8 > /dev/null; then
		mensagem "SUCESSO" "Conexão com a internet ativa"
	else
		mensagem "ERRO" "Sem acesso à internet"
		exit 1
	fi
}

# Execução
clear
verifica_distro
verifica_internet
