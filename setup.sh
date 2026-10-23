#!/usr/bin/env bash
set -euo pipefail

# Parâmetros
OS_RELEASE=/etc/os-release
FEDORA_VER=$(rpm -E %fedora)

USUARIO_REAL="${SUDO_USER:-$USER}"
HOME_REAL="$(getent passwd "$USUARIO_REAL" | cut -d: -f6)"

PACOTES_REMOVER="okular nheko rhythmbox libreoffice-*"
PACOTES_DNF="git zsh tmux shellcheck shfmt"
PACOTES_FLATPAK=""

RPM_FREE_BASE="https://mirrors.rpmfusion.org/free/fedora"
RPM_FREE_PKG="rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
RPM_FREE_URL="${RPM_FREE_BASE}/${RPM_FREE_PKG}"

RPM_NONFREE_BASE="https://mirrors.rpmfusion.org/nonfree/fedora"
RPM_NONFREE_PKG="rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"
RPM_NONFREE_URL="${RPM_NONFREE_BASE}/${RPM_NONFREE_PKG}"

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

TOTAL_SUCESSO=0
TOTAL_ERRO=0

#Cores
AZUL=$'\e[1;34m'
VERDE=$'\e[1;32m'
AMARELO=$'\e[1;33m'
VERMELHO=$'\e[1;31m'
RESETAR=$'\e[0m'

mensagem() {
	case "$1" in
		"INFO") COR="$AZUL" ;;
		"SUCESSO") COR="$VERDE" TOTAL_SUCESSO=$(( TOTAL_SUCESSO + 1 )) ;;
		"ALERTA") COR="$AMARELO" TOTAL_SUCESSO=$(( TOTAL_SUCESSO + 1 )) ;;
		"ERRO") COR="$VERMELHO" TOTAL_ERRO=$(( TOTAL_ERRO + 1 )) ;;
		*)
			printf "%s[ERRO] Mensagem não identificada\n" "$VERMELHO"
			exit 1
			;;
	esac

	printf "%s[%s]%s %s\n" "$COR" "$1" "$RESETAR" "$2."
}

verifica_distro() {
	if [[ -f "$OS_RELEASE" ]]; then
		# shellcheck disable=SC1090
		source "$OS_RELEASE"

		if [[ "$ID" == "fedora" ]]; then
			mensagem "SUCESSO" "Distribuição Fedora detectada"
		else
			mensagem "ERRO" "Script exclusivo para distribuição Fedora"
			exit 1
		fi
	else
		mensagem "ERRO" "Não foi possível identificar a distribuição"
		mensagem "INFO" "Arquivo $OS_RELEASE não encontrado"
		exit 1
	fi
}

verifica_internet() {
	if ping -c 1 8.8.8.8 &>/dev/null; then
		mensagem "SUCESSO" "Conexão com a internet ativa"
	else
		mensagem "ERRO" "Sem acesso à internet"
		exit 1
	fi
}

verifica_permissao() {
	if [ "$EUID" -eq 0 ]; then
		mensagem "SUCESSO" "Permissão root confirmada"
	else
		mensagem "ERRO" "Execute com o comando sudo"
		exit 1
	fi
}

remover_programas() {
	mensagem "INFO" "Removendo programas não utilizados"
	if dnf remove -y "$PACOTES_REMOVER" &>/dev/null; then
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

repositorios_terceiros() {
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
		mensagem "ERRO" "Flatpak não instalado"
		exit 1
	fi
}

atualizar_sistema() {
	mensagem "INFO" "Atualizando pacotes do sistema"
	if dnf upgrade -y --refresh &>/dev/null; then
		mensagem "SUCESSO" "Sistema atualizado com sucesso"
	else
		mensagem "ERRO" "Falha ao atualizar o sistema"
		exit 1
	fi
}

instalar_pacote() {
	local gerenciador=$1
	local pacote=$2

	case $gerenciador in
		"dnf")
			if rpm -q "$pacote" &>/dev/null; then
				mensagem "ALERTA" "Pacote DNF '$pacote' já está instalado"
			else
				mensagem "INFO" "Instalando pacote DNF: $pacote"
				if dnf install -y "$pacote" &>/dev/null; then
					mensagem "SUCESSO" "Pacote '$pacote' instalado com sucesso"
				else
					mensagem "ERRO" "Falha ao instalar o pacote DNF '$pacote'"
					return 1
				fi
			fi
			;;
		"flatpak")
			if flatpak list --app --columns=application | grep -q "^$pacote$"; then
				mensagem "ALERTA" "Aplicativo Flatpak '$pacote' já está instalado"
			else
				mensagem "INFO" "Instalando Flatpak: $pacote"
				if flatpak install -y flathub "$pacote" &>/dev/null; then
					mensagem "SUCESSO" "Flatpak '$pacote' instalado com sucesso"
				else
					mensagem "ERRO" "Falha ao instalar o Flatpak '$pacote'"
					return 1
				fi
			fi
			;;
		*)
			mensagem "ERRO" "Gerenciador de pacotes desconhecido: $gerenciador"
			return 1
			;;
	esac
}

instalar_lote() {
	mensagem "INFO" "Iniciando instalação de pacotes (DNF)"
	for pacote in $PACOTES_DNF; do
		instalar_pacote "dnf" "$pacote"
	done

	mensagem "INFO" "Iniciando instalação de aplicativos (Flatpak)"
	for app in $PACOTES_FLATPAK; do
		instalar_pacote "flatpak" "$app"
	done
}

instalar_via_curl() {
	local nome="$1"
	local url="$2"
	local condicao_verificacao="$3"
	local argumento_extra="${4:-}"

	if [ -n "$condicao_verificacao" ]; then
		if sudo -u "$USUARIO_REAL" env HOME="$HOME_REAL" bash -c "$condicao_verificacao" &>/dev/null; then
			mensagem "ALERTA" "$nome já está instalado para o usuário $USUARIO_REAL"
			return 0
		fi
	fi

	mensagem "INFO" "Instalando $nome via script (curl)"
	if sudo -u "$USUARIO_REAL" env HOME="$HOME_REAL" sh -c "$(curl -fsSL "$url")" "" "$argumento_extra" &>/dev/null; then
		mensagem "SUCESSO" "$nome instalado com sucesso"
	else
		mensagem "ERRO" "Falha ao instalar o $nome"
		return 1
	fi
}

instalar_codecs_multimedia() {
	mensagem "INFO" "Iniciando a instalação de codecs, multimedia e hardware"
	dnf install -y ffmpeg gstreamer1-plugins-bad-freeworld gstreamer1-plugin-openh264 --allowerasing &>/dev/null
	dnf group install -y multimedia &>/dev/null
	dnf install -y mesa-va-drivers-freeworld &>/dev/null
	mensagem "SUCESSO" "Instalado codecs, multimedia e hardware"
	return 0
}

exibir_resumo() {
	local status_final=0
	
	echo ""
	echo "=========================================="
	echo "          RESUMO DA EXECUÇÃO              "
	echo "=========================================="
	mensagem "SUCESSO" "Ações bem-sucedidas: $TOTAL_SUCESSO"
	if [ "$TOTAL_ERRO" -gt 0 ]; then
		mensagem "ERRO" "Erros encontrados: $TOTAL_ERRO"
		status_final=1
	else
		mensagem "SUCESSO" "Erros encontrados: $TOTAL_ERRO"
		status_final=0
	fi
	
	echo "=========================================="
	return "$status_final"
}

# Execução
clear
verifica_permissao
verifica_distro
verifica_internet
remover_programas
repositorios_terceiros
atualizar_sistema
instalar_codecs_multimedia
instalar_lote

instalar_via_curl "Oh My Zsh" \
	"https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
	"[ -d '$HOME_REAL/.oh-my-zsh' ]" \
	"--unattended"

instalar_via_curl "Zed Editor" \
	"https://zed.dev/install.sh" \
	"[ -x '$HOME_REAL/.local/bin/zed' ]"

exibir_resumo
