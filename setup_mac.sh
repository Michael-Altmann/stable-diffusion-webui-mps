#!/usr/bin/env bash

logi() { printf "[\033[94mINFO\033[0m]"; for i in "$@"; do printf "%s" "$i"; done; printf "\n"; }
logw() { printf "[\033[93mWARN\033[0m]"; for i in "$@"; do printf "%s" "$i"; done; printf "\n"; }
loge() { printf "[\033[91mERROR\033[0m]"; for i in "$@"; do printf "%s" "$i"; done; printf "\n"; exit 1; }

# Pre defined
GIT_MIRROR="https://hub.fastgit.xyz"
PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"

if [ -z ${GIT_MIRROR} ]; then
    GIT_MIRROR="https://github.com"
fi

# Pre detect 
for i in "uname" "git" "python3"; do
    if ! command -v $i &> /dev/null; then
        loge "uname command does not exist"
    fi
done
arch=`uname -m`
ostype=`uname -s`

if [ "$ostype" = "Darwin" ]; then
    ostype=MacOSX
fi

if [ -z ${NOT_FIRST_SDSETUP_RUN} ]; then
    if ! command -v conda &> /dev/null
    then
        echo "conda没有安装, 正在安装conda"

        # 从清华镜像源安装miniconda
        # wget https://mirror.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-$ostype-$arch.sh

        # 安装miniconda
        bash Miniconda3-latest-$ostype-$arch.sh -b -p $HOME/miniconda

        # 添加conda到环境变量
        export PATH="$PATH:$HOME/miniconda/bin"
        printf "\nexport PATH=\$PATH:\$HOME/miniconda/bin\n" >> $HOME/.bashrc

    else
        echo "conda已安装"
        # 初始化conda
        conda init
    fi
		
    # 在新的Shell里重新运行脚本 (因为第一次配置conda环境需要重启才能生效)
    exec bash -c "NOT_FIRST_SDSETUP_RUN=1 $0"
fi

export -n NOT_FIRST_SDSETUP_RUN
if ! command -v conda ;then
    export PATH="$PATH:$HOME/miniconda/bin"
fi

# 移除之前的conda虚拟环境
conda remove -n web-ui --all -y

# 创建一个新的conda虚拟环境
conda create -n web-ui python=3.10 -y

source $HOME/miniconda/etc/profile.d/conda.sh

# 激活虚拟环境
conda activate web-ui
 
# 移除之前的git仓库
rm -rf stable-diffusion-webui

# 从GitHub镜像站克隆仓库
git clone "$GIT_MIRROR/AUTOMATIC1111/stable-diffusion-webui"

# 进入仓库目录
cd stable-diffusion-webui

echo "============================================="
echo "============================================="
echo "===========STABLE DIFFUSION MODEL============"
echo "============================================="
echo "============================================="

# 询问用户是否已安装模型 （如果用户选择下载，需要将下载得到的model.ckpt文件手动挪到文件夹里，如果可能：直接提取文件到目标文件夹。目前OneDrive还不支持直链提取。）

cat << EOF
如果你已经下载了模型, 现在可以把模型文件移动到
stable-diffusion-webui/models/Stable-diffusion/
如果没有下载模型，复制这段链接到浏览器里来下载模型：
https://fancade-my.sharepoint.com/:u:/g/personal/maltmann_fancade_onmicrosoft_com/EWrI4OZzaVNBnkiNLuPtR9cBRKjWTxYICstvaziMo03MaQ?e=ljQWGk
echo 在下载完成后，手动将模型文件移动到
stable-diffusion-webui/models/Stable-diffusion/
EOF

while true; do
    read -p "已经正确放置模型了吗? (y/n) " yn
    case $yn in
        [Yy]* ) echo "跳过模型下载"; break;;
        [Nn]* ) echo "你可以随时通过OneDrive下载模型"; break;;
        * ) echo "请输入y或n.";;
    esac
done

# 从GitHub镜像站克隆需要的仓库 （这一步同样有问题）   浅克隆可以避免克隆整个仓库，只把对应分支的文件克隆下来
git clone "$GIT_MIRROR/CompVis/stable-diffusion" "repositories/stable-diffusion" --depth=1
 
git clone "$GIT_MIRROR/CompVis/taming-transformers" "repositories/taming-transformers" --depth=1

git clone "$GIT_MIRROR/sczhou/CodeFormer" "repositories/CodeFormer" --depth=1
    
git clone "$GIT_MIRROR/salesforce/BLIP" "repositories/BLIP" --depth=1

git clone "$GIT_MIRROR/Birch-san/k-diffusion" "repositories/k-diffusion" --depth=1

# 在继续之前，检查: (1)是否安装了模型 (2)是否克隆了仓库

for i in "repositories/stable-diffusion" "repositories/taming-transformers" "repositories/CodeFormer" "repositories/BLIP"; do
    if [ ! -d "$i" ]; then
        loge "$i repository does not exist !"
    fi
done
ckpt_list=`find "models/" -name "\*.ckpt"`
if [ ! -z "$ckpt_list" ]; then
     logw "models dir have no ckpt files"
# 这里要实现的功能是，检查models 或 models/stable-diffusion中是否有后缀名为.ckpt的文件，同时在repositries中是否有stable-diffuion等四个仓库。 这段中对.ckpt文件的筛选有问题。

    echo "所有文件校验完成，开始安装"
else
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "模型/仓库校验失败"
    echo "请检查模型是否存在 && 仓库是否克隆"
    echo "你可以在这里找到模型: stable-diffusion-webui/models/Stable-diffusion/"
    echo "你可以在这里找到仓库: stable-diffusion-webui/repositories/"
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    # exit 1
fi

# 安装依赖

cd ~/

if [ -z "$PIP_MIRROR" ]; then
    pip install -r "requirements.txt"
else
    pip install -r "requirements_mirror.txt" -i "$PIP_MIRROR"
fi 

# 移除torch和所有相关的包
pip uninstall torch torchvision torchaudio -y

# 一般情况下应该安装最新的Nightly版本,
# 但是现在最新版本有性能问题.
# 因此会使用老版本.
# TODO: go back once fixed on PyTorch side

pip install --pre torch==1.13.0.dev20220922 torchvision==0.14.0.dev20220924 -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html --no-deps

# 激活MPS_FALLBACK conda环境变量
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1 -y

# 重启conda环境使环境变量生效
conda deactivate -y
conda activate web-ui -y

# 检查配置变量是否成功
if [ -z "$PYTORCH_ENABLE_MPS_FALLBACK" ]; then
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "PYTORCH_ENABLE_MPS_FALLBACK 变量没有设置"
    echo "这意味着将使用CPU运算"
    echo "使用以下指令修复:"
    echo "conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1"
    echo "或者尝试重新运行脚本"
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    exit 1
fi

# 创建一个shell脚本运行Web UI
cat << EOF > run_webui_mac.sh
#!/usr/bin/env bash

# This should not be needed since it's configured during installation, but might as well have it here.
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1

# Activate conda environment
conda activate web-ui

# Pull the latest changes from the repo
git pull --rebase

# Run the web ui
python webui.py --precision full --no-half --use-cpu GFPGAN CodeFormer BSRGAN ESRGAN SCUNet \$@

# Deactivate conda environment
conda deactivate
EOF

# 给予脚本执行权限
chmod +x run_webui_mac.sh

echo "============================================="
echo "============================================="
echo "==============MORE INFORMATION==============="
echo "============================================="
echo "============================================="
echo "如果想要再次运行Web UI, 输入以下指令:"
echo "./stable-diffusion-webui/run_webui_mac.sh"
echo "或者"
echo "cd stable-diffusion-webui && ./run_webui_mac.sh"
echo "============================================="
echo "============================================="
echo "============================================="
echo "============================================="


# 运行Web UI
python webui.py --precision full --no-half --use-cpu GFPGAN CodeFormer BSRGAN ESRGAN SCUNet
