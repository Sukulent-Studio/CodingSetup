#! /bin/bash

check_pkgs() {
    local check_cmd="" # Команда для проверки установки пакета
    local in_arr_name="" # Имя переменной массива необходимых пакетов
    local out_arr_name="" # Имя переменной массива неустановленных пакетов

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -c|--command)
            check_cmd="$2"
            shift 2
            ;;

            -a|--array)
            in_arr_name="$2"
            shift 2
            ;;

            -o|--output)
            out_arr_name="$2"
            shift 2
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

    declare -n in_arr_ref="$in_arr_name"
    declare -n out_arr_ref="$out_arr_name"

    local installed_pkgs=()

    for pkg in "${in_arr_ref[@]}"; do
        if eval "$check_cmd"; then
            continue
        else
            installed_pkgs+=("$pkg")
        fi
    done

    out_arr_ref=("${installed_pkgs[@]}")
}
