#! /bin/bash

source "${MAIN_SCRIPT_DIR}/scripts/checkPackages.sh"

description="Настройка агента Report-Maker"
agent_name="Report-Maker"
pkgs=("typst" "cargo" "just" "rust-wasm" "rust" "python" "python-pillow" "poppler" "ttf-liberation") 
pkgs_typst=("modern-g7-32" "cetz" "gost-table" "tituls")

local_typst_pkgs_dir="${HOME}/.local/share/typst/packages/local"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--description)
        echo "$description"
        exit 0
        ;;

        --)
        shift
        break
        ;;

        -*)
        echo "Unknown flag ${1}" >&2
        break;;

        *)
        break
        ;;
    esac
done

ni_pkgs=()
ni_pkgs_typst=()

inst_pkgs() {
    if [[ "${#ni_pkgs[@]}" -gt 0 ]]; then
        echo "Установка системных зависимостей: ${ni_pkgs[*]}"
        sudo pacman -S --needed "${ni_pkgs[@]}"
    fi

    mkdir -p "$local_typst_pkgs_dir"

    local temp_dir
    temp_dir=$(mktemp -d)
    # Гарантированная очистка при выходе или ошибке
    trap 'rm -rf "$temp_dir"' EXIT

    for pkg in "${ni_pkgs_typst[@]}"; do
        echo "Обработка Typst-пакета: $pkg"
        local local_linking=false
        local link_from=""
        local version=""
        local to_copy=""

        case "$pkg" in
            "modern-g7-32")
                git clone https://github.com/typst-gost/modern-g7-32.git "${temp_dir}/modern-g7-32"
                to_copy=("typst.toml" "src" "assets" "template")
                version=$(awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' "${temp_dir}/modern-g7-32/typst.toml")
                ;;
            "cetz")
                git clone --recursive https://github.com/cetz-package/cetz.git "${temp_dir}/cetz"
                (cd "${temp_dir}/cetz" && just install)
                continue 
                ;;
            "gost-table")
                local_linking=true
                link_from="${MAIN_SCRIPT_DIR}/ai/opencode/agents/report-maker/gost-table"
                version=$(awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' "${link_from}/typst.toml" 2>/dev/null || echo "local")
                ;;
            "tituls")
                local_linking=true
                link_from="${MAIN_SCRIPT_DIR}/ai/opencode/agents/report-maker/tituls"
                version=$(awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' "${link_from}/typst.toml" 2>/dev/null || echo "local")
                ;;
            *)
                echo "Неизвестный пакет: $pkg, пропуск."
                continue
                ;;
        esac

        if [[ -z "$version" ]]; then
            echo "ОШИБКА: Не удалось определить версию для пакета $pkg. Пропуск."
            continue
        fi

        local target_dir="${local_typst_pkgs_dir}/${pkg}/${version}"

        if $local_linking; then
            echo "Создание симлинка для $pkg (версия $version)"
            mkdir -p "$(dirname "$target_dir")"
            # Удаляем старую ссылку/папку, если есть, чтобы избежать ошибок
            rm -rf "$target_dir"
            ln -s "$link_from" "$target_dir"
        else
            echo "Копирование файлов для $pkg (версия $version)"
            mkdir -p "$target_dir"
            for copy_name in "${to_copy[@]}"; do
                cp -r "${temp_dir}/${pkg}/${copy_name}" "$target_dir/"
            done
        fi
    done

    # Очистка произойдёт автоматически благодаря trap
    echo "Настройка Typst-пакетов завершена."
}

while true; do
    clear
    # agent_installed=false

    check_pkgs -c 'pacman -Qq "$pkg" > /dev/null 2>&1' -a "pkgs" -o "ni_pkgs"
    check_pkgs -c '[ -d "${local_typst_pkgs_dir}/${pkg}" ] && [ -z "$(find "${local_typst_pkgs_dir}/${pkg}" -maxdepth 0 -empty)" ]' -a pkgs_typst -o "ni_pkgs_typst"

    choose=()
    if [[ "${#ni_pkgs[@]}" -gt 0 || "${#ni_pkgs_typst[@]}" -gt 0 ]]; then
        choose+=("Install dependencies")
    else
        choose+=("Remove dependencies")
    fi

    if [[ ! -d "${HOME}/.config/opencode/agent" || ! -f "${HOME}/.config/opencode/agent/${agent_name}.md" ]]; then
        choose+=("Install agent")
    elif [[ "${#ni_pkgs[@]}" -gt 0 || "${#ni_pkgs_typst[@]}" -gt 0 ]]; then
        choose+=("Remove agent")
        # agent_installed=true
    else
        choose+=("Remove agent AND deps")
        # agent_installed=true
    fi
    choose+=("Exit")

    gum style \
        "$description"

    action=$(gum choose "${choose[@]}")

    case "$action" in
        "Install dependencies")
        inst_pkgs
        ;;
        "Remove dependencies")
        ;;
        "Install agent")
        if inst_pkgs; then
            mkdir -p "${HOME}/.config/opencode/agent" # TODO Добавить переменную в скрипте выше
            rm -f "${HOME}/.config/opencode/agent/${agent_name}.md"
            ln -s "${MAIN_SCRIPT_DIR}/ai/opencode/agents/report-maker/${agent_name}.md" "${HOME}/.config/opencode/agent/${agent_name}.md"

            mkdir -p "${HOME}/.config/opencode/docs" # TODO Добавить переменную в скрипте выше
            rm -rf "${HOME}/.config/opencode/docs/${agent_name}"
            ln -s "${MAIN_SCRIPT_DIR}/ai/opencode/agents/report-maker/docs" "${HOME}/.config/opencode/docs/${agent_name}"

            mkdir -p "${HOME}/.config/opencode/tools" # TODO Добавить переменную в скрипте выше
            rm -rf "${HOME}/.config/opencode/tools/${agent_name}"
            ln -s "${MAIN_SCRIPT_DIR}/ai/opencode/agents/report-maker/tools" "${HOME}/.config/opencode/tools/${agent_name}"
        else
            echo "Ошибка при установке зависимостей"
        fi
        ;;
        "Remove agent")
        ;;
        "Remove agent AND deps")
        ;;
        "Exit")
        clear
        exit 0
        ;;
        *)
        continue
        ;;
    esac

    echo -e "\nНажмите Enter для продолжения..."
    read -r
done
