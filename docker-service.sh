#!/bin/bash

function __usage() {
  local _script_name="$0"
  cat <<EOL >&2
${_script_name} is Docker container development assist tool.

Usage:
    ${_script_name} [[command] [arguments]]

Command:
    init                    initialize configuration file .docker-servicerc
    boot|boot-fg            docker container run
    boot-bg                 docker container run -d=true
    onceboot|onceboot-fg    docker container run --rm
    onceboot-bg             docker container run --rm -d=true
    build                   docker image build
    rebuild                 rebuild docker image
    start                   docker container start
    stop                    docker container stop
    restart                 docker container restart
    enable                  docker container enable
    disable                 docker container disable
    container-rm            docker container rm
    image-rm                docker image rm
    purge                   docker container rm -f && docker image rm
    login                   docker container login in USER
    exec                    docker container exec

    exec e.g)
        $ ${_script_name} exec ls -la
EOL
}

function __init() {

  if [ -z "${CONTAINER}" ] || \
     [ -z "${REPOSITRY}" ]; then
    echo "Invalid variable in ${_RCFILE}" >&2
  fi

  local _answer _overwrite
  echo -n "exist ${_RCFILE} alreay. overwrite?[y/n/E]: "
  read -r _answer
  case ${_answer} in
    [Yy]|[Yy][Ee][Ss] )
      _overwrite="1"
    ;;
    [Ee]|[Ee][Dd][Ii][Tt] )
      _overwrite="2"
    ;;
    [Nn]|[Nn][Oo] )
      _overwrite="0"
    ;;
    * )
      _overwrite="2"
    ;;
  esac

  if [ "${_overwrite}" -eq "1" ]; then
    (
      echo "REPOSITRY="
      echo "CONTAINER="
      echo "VERSION="
    ) > "${_RCFILE}"
    eval ${EDITOR:-vi} "${_RCFILE}"

    . "${_RCFILE}"
  elif [ "${_overwrite}" -eq "2" ]; then
    eval ${EDITOR:-vi} "${_RCFILE}"
  fi

}

function __echo_exec() {
  echo "$@" >&2
  eval "$@"
}

function __set_global_variables() {
  _BASE_DIR="$(dirname "$(readlink -f "$0")")"
  _IMAGE_NAME="${REPOSITRY}/${CONTAINER}:${VERSION}"
  _HOSTNAME="$(hostname -f)"
}

function __container_build() {
  __echo_exec docker image build \
    --tag="${_IMAGE_NAME}" \
    --build-arg HTTP_PROXY="${HTTP_PROXY}" \
    --build-arg http_proxy="${http_proxy}" \
    --build-arg HTTPS_PROXY="${HTTP_PROXY}" \
    --build-arg https_proxy="${https_proxy}" \
    --build-arg FTP_PROXY="${FTP_PROXY}" \
    --build-arg ftp_proxy="${ftp_proxy}" \
    --build-arg NO_PROXY="${NO_PROXY}" \
    --build-arg no_proxy="${no_PROXY}" \
    "${_DOCKER_BUILD_OPTS}" \
    .
}

function __container_run() {
  local _docker_opts
  if [ ! -z "${HTTP_PROXY}" ]; then
    _docker_opts="${_docker_opts} -e HTTP_PROXY=${HTTP_PROXY}"
  fi

  if [ ! -z "${http_proxy}" ]; then
    _docker_opts="${_docker_opts} -e http_proxy=${http_proxy}"
  fi

  if [ ! -z "${HTTPS_PROXY}" ]; then
    _docker_opts="${_docker_opts} -e HTTPS_PROXY=${HTTPS_PROXY}"
  fi

  if [ ! -z "${https_proxy}" ]; then
    _docker_opts="${_docker_opts} -e https_proxy=${https_proxy}"
  fi

  if [ ! -z "${FTP_PROXY}" ]; then
    _docker_opts="${_docker_opts} -e FTP_PROXY=${FTP_PROXY}"
  fi

  if [ ! -z "${ftp_proxy}" ]; then
    _docker_opts="${_docker_opts} -e ftp_proxy=${ftp_proxy}"
  fi

  if [ ! -z "${NO_PROXY}" ]; then
    _docker_opts="${_docker_opts} -e NO_PROXY=${NO_PROXY}"
  fi

  if [ ! -z "${no_proxy}" ]; then
    _docker_opts="${_docker_opts} -e no_proxy=${no_proxy}"
  fi

  local _arguments _docker_opts_flag _exec_cmd _exec_cmd_flag
  local _docker_opts_flag="0"
  local _exec_cmd_flag="0"
  for _arguments in $@; do
    case "${_arguments}" in
      --docker-opts )
        _docker_opts_flag="1"
        _exec_cmd_flag="0"
      ;;
      --exec )
        _docker_opts_flag="0"
        _exec_cmd_flag="1"
      ;;
      * )
        if [ "${_exec_cmd_flag}" -eq "1" ]; then
          if [ -z "${_exec_cmd}" ]; then
            _exec_cmd="${_arguments}"
          else
            _exec_cmd="${_exec_cmd} ${_arguments}"
          fi
        else
          if [ -z "${_docker_opts}" ]; then
            _docker_opts="${_arguments}"
          else
            _docker_opts="${_docker_opts} ${_arguments}"
          fi
        fi
      ;;
    esac
  done

  _docker_opts="${_docker_opts} ${_BOOT_STATE} ${_ONCE}"
  __echo_exec docker container run \
    -it --name "${CONTAINER}" \
    --env-file "${_BASE_DIR}/etc/docker-container.conf" \
    "${_docker_opts}" "${_IMAGE_NAME}" "${_exec_cmd}"
}

function __container_start() {
  __echo_exec docker container start "${CONTAINER}"
}

function __container_stop() {
  __echo_exec docker container stop "${CONTAINER}"
}

function __container_restart() {
  __echo_exec docker container restart "${CONTAINER}"
}

function __container_enable() {
  __echo_exec docker container update --restart=always "${CONTAINER}"
}

function __container_disable() {
  __echo_exec docker container update --restart=no "${CONTAINER}"
}

function __container_remove() {
  __echo_exec docker container rm "${CONTAINER}"
}

function __image_remove() {
  __echo_exec docker image rm "${_IMAGE_NAME}"
}

function __container_exec() {
  __echo_exec docker container exec -it "${CONTAINER}" "$@"
}

function __main() {
  local _cnt_arguments="$#"
  local _command="$1"
  shift 1
  local _arguments="$@"

  _RCFILE=".docker-servicerc"

  if [ -s "${_RCFILE}" ]; then
    . "${_RCFILE}"

    VERSION="${VERSION:-latest}"
    __set_global_variables

    if [ "${_cnt_arguments}" -ge 1 ]; then
      case "${_command}" in
        init )
          __init
        ;;
        boot|boot-[bf]g|onceboot|onceboot-[bf]g )
          case "${_command}" in
            boot|boot-fg )
              _BOOT_STATE="--detach=false"
              _ONCE="--rm=false"
            ;;
            boot-bg )
              _BOOT_STATE="--detach=true"
              _ONCE="--rm=false"
            ;;
            onceboot|onceboot-fg )
              _BOOT_STATE="--detach=false"
              _ONCE="--rm=true"
            ;;
            onceboot-bg )
              _BOOT_STATE="--detach=true"
              _ONCE="--rm=true"
            ;;
          esac

          __container_run "${_arguments}"
        ;;
        build )
          _DOCKER_BUILD_OPTS="${_arguments}"
          __container_build
        ;;
        rebuild )
          local readonly _before_image _after_image
          _before_image="$( \
            docker image ls --format "{{.ID}} {{.Repository}}:{{.Tag}}" \
              | grep "${_IMAGE_NAME}" \
              | awk '{print $1}' \
          )"
          _DOCKER_BUILD_OPTS="${_arguments}"
          __container_build

          _after_image="$( \
            docker image ls --format "{{.ID}} {{.Repository}}:{{.Tag}}" \
              | grep "${_IMAGE_NAME}" \
              | awk '{print $1}' \
          )"
          if [ "${_before_image}" != "${_after_image}" ]; then
            if [ ! -z "${_before_image}" ]; then
              __echo_exec docker image rm "${_before_image}"
            fi
          fi
        ;;
        start )
          __container_start
        ;;
        stop )
          __container_stop
        ;;
        restart )
          __container_restart
        ;;
        enable )
          __container_enable
        ;;
        disable )
          __container_disable
        ;;
        container-rm )
          __container_remove
        ;;
        image-rm )
          __image_remove
        ;;
        purge )
          __container_remove && \
          __image_remove
        ;;
        login )
          local _login_user _login_shell
          _login_user="$( \
            docker container inspect -f "{{.Config.User}}" "${CONTAINER}" \
          )"
          _login_shell="$( \
            __container_exec "cat /etc/passwd \
              | grep "${_login_user}" \
              | awk -F ':' '{print \$NF}' \
              | tr -d \"\\r\"" 2> /dev/null \
            )"
          __container_exec "${_login_shell}"
        ;;
        exec )
          __container_exec "${_arguments}"
        ;;
        * )
          echo "missing operand" >&2
        ;;
      esac
    else
      __usage
    fi
  else
    if [ "${_cnt_arguments}" -ge 1 ]; then
      case "${_command}" in
        init )
          __init
        ;;
        * )
          __usage
        ;;
      esac
    else
      __usage
    fi
  fi
}

__main "$@"
