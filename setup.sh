#!/usr/bin/env bash
set -euo pipefail

# Parâmetros
OS_RELEASE=/etc/os-release
FEDORA_VER=$(rpm -E %fedora)

PACOTES_REMOVER="okular nheko rhythmbox libreoffice-*"

RPM_FREE_BASE="https://mirrors.rpmfusion.org/free/fedora"
RPM_FREE_PKG="rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
RPM_FREE_URL="${RPM_FREE_BASE}/${RPM_FREE_PKG}"

RPM_NONFREE_BASE="https://mirrors.rpmfusion.org/nonfree/fedora"
RPM_NONFREE_PKG="rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
RPM_NONFREE_URL="${RPM_NONFREE_BASE}/${RPM_NONFREE_PKG}"

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

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
if ping -c 1 8.8.8.8 &> /dev/null; then
		mensagem "SUCESSO" "Conexão com a internet ativa"
	else
		mensagem "ERRO" "Sem acesso à internet"
		exit 1
	fi
}

verifica_permissao(){
	if [ ! "$EUID" -ne 0 ]; then
		mensagem "SUCESSO" "Permissão root confirmada"
	else
		mensagem "ERRO" "Execute com o comando sudo"
		exit 1
	fi
}

remover_programas(){
	if dnf remove -y $PACOTES_REMOVER &>/dev/null; then
		mensagem "SUCESSO" "Aplicativos removidos com sucesso"
	else
		mensagem "ERRO" "Falha ao remover os pacotes"
		exit 1
	fi
	
	if dnf autoremove -y &>/dev/null; then
		mensagem "SUCESSO" "Limpeza de dependências concluída"
	else
		mensagem "ERRO" "Falha ao executar o autoremove"
	fi
}

repositorios_terceiros(){
	#RPM Fusion Free
	if rpm -q rpmfusion-free-release &>/dev/null; then
		mensagem "ALERTA" "Repositório RPM Fusion Free já está configurado"
	else
		mensagem "INFO" "Configurando o repositório RPM Fusion Free"
	
		if dnf install -y "$RPM_FREE_URL" &>/dev/null; then
			mensagem "SUCESSO" "RPM Fusion Free instalado"
  		else
    		mensagem "ERRO" "Falha no RPM Fusion Free"
      		exit 1
  		fi
	fi
	#RPM Fusion Nonfree
	if rpm -q rpmfusion-nonfree-release &>/dev/null; then
		mensagem "ALERTA" "Repositório RPM Fusion Nonfree já está configurado"
	else
		mensagem "INFO" "Configurando o repositório RPM Fusion Nonfree"
	
		if dnf install -y "$RPM_NONFREE_URL" &>/dev/null; then
			mensagem "SUCESSO" "RPM Fusion Nonfree instalado"
  		else
    		mensagem "ERRO" "Falha no RPM Fusion Nonfree"
      		exit 1
  		fi
	fi
	#Flatpak
	if command -v flatpak &>/dev/null; then
  		if flatpak remote-list | grep -q "^flathub"; then
    		mensagem "ALERTA" "Flathub já está configurado"
  		else
    		mensagem "INFO" "Configurando Flathub"
      		if flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"; then
        		mensagem "SUCESSO" "Flathub adicionado"
    		else
      			mensagem "ERRO" "Falha ao adicionar Flathub"
         		exit 1
    		fi
  		fi
	else
  		mensage "ERRO" "Flatpak não instalado"
    	exit 
	fi
}

# Execução
clear
verifica_permissao
verifica_distro
verifica_internet
remover_programas
repositorios_terceiros