#!/usr/bin/env bash -l

if [ -z ${NOT_FIRST_SDSETUP_RUN} ]; then
    if ! command -v conda &> /dev/null
    then
        echo "conda没有安装, 正在安装conda"

        # Install conda
        wget https://mirror.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-MacOSX-arm64.sh

        # Install conda
        bash Miniconda3-latest-MacOSX-arm64.sh -b -p $HOME/miniconda

        # Add conda to path
        export PATH="$HOME/miniconda/bin:$PATH"

    else
        echo "conda已安装"

    fi

    # Initialize conda
    conda init

    # Rerun the shell script with a new shell (required to apply conda environment if conda init was run for the first time)
    exec -c bash -c "NOT_FIRST_SDSETUP_RUN=1 \"$0\""
fi

export -n NOT_FIRST_SDSETUP_RUN

# Remove previous conda environment
conda remove -n web-ui --all

# Create conda environment
conda create -n web-ui python=3.10

# Activate conda environment
conda activate web-ui

# Remove previous git repository
rm -rf stable-diffusion-webui

# Clone the repo
git clone https://hub.fastgit.xyz/github.com/AUTOMATIC1111/stable-diffusion-webui.git

# Enter the repo
cd stable-diffusion-webui

echo "============================================="
echo "============================================="
echo "===========STABLE DIFFUSION MODEL============"
echo "============================================="
echo "============================================="

# Prompt the user to ask if they've already installed the model
echo "如果你已经下载了模型, 现在可以把模型文件移动到 stable-diffusion-webui/models/Stable-diffusion/"
echo "如果你还没下载模型,可以输入n在OneDrive下载模型"
while true; do
    read -p "已经下载了模型吗? (y/n) " yn
    case $yn in
        [Yy]* ) echo "跳过模型下载"; break;;
        [Nn]* ) echo "下载模型"; 
        # Prompt the user for their hugging face token and store it in a variable
        echo "复制这段链接到浏览器里来下载模型：
        https://fancade-my.sharepoint.com/:u:/g/personal/maltmann_fancade_onmicrosoft_com/EWrI4OZzaVNBnkiNLuPtR9cBRKjWTxYICstvaziMo03MaQ?e=ljQWGk"
        break;;
        * ) echo "请输入y或n.";;
    esac
done

# Clone required repos
git clone https://gitclone.com/github.com/CompVis/stable-diffusion.git repositories/stable-diffusion
 
git clone https://gitclone.com/github.com/CompVis/taming-transformers.git repositories/taming-transformers

git clone https://gitclone.com/github.com/sczhou/CodeFormer.git repositories/CodeFormer
    
git clone https://gitclone.com/github.com/salesforce/BLIP.git repositories/BLIP

git clone https://gitclone.com/github.com/Birch-san/k-diffusion repositories/k-diffusion

# Before we continue, check if 1) the model is in place 2) the repos are cloned
if ( [ -f "models/ "*.ckpt" " ] || [ -f "models/Stable-diffusion/ "*.ckpt" " ] ) && [ -d "repositories/stable-diffusion" ] && [ -d "repositories/taming-transformers" ] && [ -d "repositories/CodeFormer" ] && [ -d "repositories/BLIP" ]; then
    echo "所有文件校验完成，开始安装"
else
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "模型/仓库校验失败"
    echo "请检查模型是否存在，仓库是否克隆"
    echo "你可以在这里找到模型: stable-diffusion-webui/models/Stable-diffusion/"
    echo "你可以在这里找到仓库: stable-diffusion-webui/repositories/"
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    exit 1
fi

# Install dependencies
pip install diffusers basicsr gfpgan gradio numpy Pillow realesrgan torch omegaconf pytorch_lightning diffusers invisible-watermark scikit-image>=0.19 fonts font-roboto

pip install timm==0.4.12 fairscale==0.4.4 piexif

pip install git+https://gitclone.com/github.com/openai/CLIP.git@d50d76daa670286dd6cacf3bcd80b5e4823fc8e1

pip install git+https://gitclone.com/github.com/TencentARC/GFPGAN.git@8d2447a2d918f8eba5a4a01463fd48e45126a379

# Remove torch and all related packages
pip uninstall torch torchvision torchaudio -y

# Normally, we would install the latest nightly build of PyTorch here,
# But there's currently a performance regression in the latest nightly releases.
# Therefore, we're going to use this old version which doesn't have it.
# TODO: go back once fixed on PyTorch side
pip install --pre torch==1.13.0.dev20220922 torchvision==0.14.0.dev20220924 -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html --no-deps

# Missing dependencie(s)
pip install gdown fastapi psutil

# Activate the MPS_FALLBACK conda environment variable
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1

# We need to reactivate the conda environment for the variable to take effect
conda deactivate
conda activate web-ui

# Check if the config var is set
if [ -z "$PYTORCH_ENABLE_MPS_FALLBACK" ]; then
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "The PYTORCH_ENABLE_MPS_FALLBACK variable is not set."
    echo "This means that the script will either fall back to CPU or fail."
    echo "To fix this, please run the following command:"
    echo "conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1"
    echo "Or, try running the script again."
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    exit 1
fi

# Create a shell script to run the web ui
echo "#!/usr/bin/env bash -l

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
" > run_webui_mac.sh

# Give run permissions to the shell script
chmod +x run_webui_mac.sh

echo "============================================="
echo "============================================="
echo "==============MORE INFORMATION==============="
echo "============================================="
echo "============================================="
echo "If you want to run the web UI again, you can run the following command:"
echo "./stable-diffusion-webui/run_webui_mac.sh"
echo "or"
echo "cd stable-diffusion-webui && ./run_webui_mac.sh"
echo "============================================="
echo "============================================="
echo "============================================="
echo "============================================="


# Run the web UI
python webui.py --precision full --no-half --use-cpu GFPGAN CodeFormer BSRGAN ESRGAN SCUNet