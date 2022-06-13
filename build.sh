#!/bin/bash

if [[ -z "$COULMNS" ]]; then
  COLUMNS=$(tput cols)
fi

function banner() {
  if [[ $FIGLET_ENABLED == "true" && $LOLCAT_ENABLED == "true" ]]; then
    ${FIGLET_CLI} -f ./contrib/figlet-fonts/3d.flf -w $COLUMNS $1 | $LOLCAT_CLI
  elif [[ $FIGLET_ENABLED == "true" ]]; then
    ${FIGLET_CLI} -f ./contrib/figlet-fonts/3d.flf -w $COLUMNS $1
  else
    echo "+------------------------------------------+"
    printf "|$(tput bold) %-40s $(tput sgr0)|\n" "$@"
    echo "+------------------------------------------+"
  fi
}

function hr() {
  printf %"$COLUMNS"s | tr " " "-"
}

function err_msg() {
  echo "Error:"
  echo $1
}

AWSCLI=aws
JQCLI=jq
KUSTOMIZECLI=kustomize
DOCKERCLI="docker"

FIGLET_CLI=figlet
FIGLET_ENABLED="true"
LOLCAT_CLI=lolcat
LOLCAT_ENABLED="true"

command -v ${FIGLET_CLI} >/dev/null 2>&1 || FIGLET_ENABLED="false"
command -v ${LOLCAT_CLI} >/dev/null 2>&1 || LOLCAT_ENABLED="false"

SCRIPTNAME=$(basename $0)
PUSH_FLAG=false
UPDATE_GITOPS_FLAG=false
GITOPS_USER=
GITOPS_REPO=
GITOPS_PATH=ops/auth/kustomize/overlay/dev
GITOPS_IMAGE=mkp-auth

PUSH_FLAG=false
VERSION=
VERSION_BASE=
VERSION_POSTFIX=

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT=$SCRIPT_DIR
cd "${PROJECT_ROOT}"

IMAGE_NAME='kkr/kong'
IMAGE_TAG="latest"
AWS_REGION="ap-northeast-2"
AWS_PROFILE=""
AWS_PROFILE_OPT=""

usage() {
  echo "${SCRIPTNAME} [OPTIONS]"
  echo "Build Docker image."
  echo "-h                This help screen."
  echo "-p / --push       Push image to ECR."
  echo "--postfix         Set VERSION Postfix."
  echo "--version         Set VERSION"
  echo "--profile         Set aws profile"
  exit 0
}

########################## long 옵션 처리 부분 #############################

SHORT_ARGS=""
while true; do
  [ $# -eq 0 ] && break
  case $1 in
  --version)
    shift
    case $1 in -* | "") usage ;; esac
    VERSION_BASE=$1
    shift
    continue
    ;;
  --postfix)
    shift
    case $1 in -* | "") usage ;; esac
    VERSION_POSTFIX=$1
    shift
    continue
    ;;
  --push)
    PUSH_FLAG=true
    shift
    continue
    ;;
  --profile)
    shift
    case $1 in -* | "") usage ;; esac
    AWS_PROFILE=$1
    AWS_PROFILE_OPT=" --profile ${AWS_PROFILE} "
    shift
    continue
    ;;
  --)
    IFS=$(echo -e "\a")
    SHORT_ARGS=$SHORT_ARGS$([ -n "$SHORT_ARGS" ] && echo -e "\a")$*
    break
    ;;
  --*)
    err_msg "Invalid option: $1"
    usage
    ;;
  esac

  SHORT_ARGS=$SHORT_ARGS$([ -n "$SHORT_ARGS" ] && echo -e "\a")$1
  shift
done

IFS=$(echo -e "\a")
set -f
set -- $SHORT_ARGS
set +f
IFS=$(echo -e " \n\t")

########################## short 옵션 처리 부분 #############################

while getopts "p" opt; do
  case $opt in
  p)
    PUSH_FLAG=true
    ;;
  :) ;;

  \?)
    err_msg "Invalid option: -$OPTARG"
    usage
    ;;
  esac
done

shift $((OPTIND - 1))

########################## short ######################################

set -e
command -v ${JQCLI} >/dev/null 2>&1 || {
  echo >&2 "I require jq but it's not installed. Please run 'brew install jq'."
  exit 1
}
command -v ${AWSCLI} >/dev/null 2>&1 || {
  echo >&2 "I require aws but it's not installed. Please run 'pip install --user --upgrade awscli'."
  exit 1
}
command -v ${DOCKERCLI} >/dev/null 2>&1 || {
  echo >&2 "I require docker but it's not installed. Please download 'https://download.docker.com/mac/stable/Docker.dmg'."
  exit 1
}
command -v ${POETRY} >/dev/null 2>&1 || {
  echo >&2 "I require poetry but it's not installed. Please install poetry in https://python-poetry.org/ ."
  exit 1
}

if [[ -z "${VERSION_BASE}" ]]; then
  VERSION_BASE=$(cat VERSION)
fi

if [[ ! -z "${VERSION_POSTFIX}" ]]; then
  VERSION="${VERSION_BASE}-${VERSION_POSTFIX}"
else
  VERSION="${VERSION_BASE}"
fi

AWS_ACCOUNT_ID=$(${AWSCLI} sts get-caller-identity $AWS_PROFILE_OPT | ${JQCLI} -r .Account)

banner $IMAGE_NAME
banner $VERSION

echo "UPDATE_GITOPS_FLAG= $UPDATE_GITOPS_FLAG"
echo "GITOPS_USER=        $GITOPS_USER       "

aws ecr get-login-password --region $AWS_REGION $AWS_PROFILE_OPT |
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

${DOCKERCLI} build -t ${IMAGE_NAME} . -f ./Dockerfile
${DOCKERCLI} tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:${VERSION}"

set +e
aws ecr describe-repositories --repository-names $IMAGE_NAME $AWS_PROFILE_OPT 2>&1 >/dev/null
STATUS=$?
if [[ ! "${STATUS}" -eq 0 ]]; then
  aws ecr create-repository --repository-name $IMAGE_NAME $AWS_PROFILE_OPT
fi
set -e

REPO_URI=$(${AWSCLI} ecr describe-repositories $AWS_PROFILE_OPT | ${JQCLI} -r ".repositories[] | select(.repositoryName | contains(\"$IMAGE_NAME\")) | .repositoryUri")
${DOCKERCLI} tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REPO_URI}:${IMAGE_TAG}"
${DOCKERCLI} tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REPO_URI}:${VERSION}"

# echo '---------------------------------------'
hr
echo "${IMAGE_NAME}:${IMAGE_TAG}"
echo "${IMAGE_NAME}:${VERSION}"
echo "${REPO_URI}:${IMAGE_TAG}"
echo "${REPO_URI}:${VERSION}"
hr
# echo '---------------------------------------'

if [[ $PUSH_FLAG == 'true' ]]; then
  ${DOCKERCLI} push "${REPO_URI}:${IMAGE_TAG}"
  ${DOCKERCLI} push "${REPO_URI}:${VERSION}"
fi
