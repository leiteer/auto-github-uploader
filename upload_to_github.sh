#!/bin/bash

# 确保脚本在发生错误时停止执行
set -e

# 配置 SSL 验证和代理设置
echo "配置 Git SSL 设置..."
git config --global http.sslVerify false

# 配置代理（根据需要修改代理地址和端口）
echo "配置代理设置..."
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 检查网络连接（Windows 和 Unix 系统通用）
echo "检查网络连接..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows 环境
    # 尝试多种方式检查连接
    if ! ping -n 1 github.com > /dev/null 2>&1; then
        if ! curl -s https://github.com > /dev/null; then
            if ! wget -q --spider https://github.com; then
                echo "无法连接到 GitHub，请检查："
                echo "1. 是否已连接到网络"
                echo "2. 是否需要配置代理"
                echo "3. 是否可以访问 github.com"
                echo ""
                echo "您可以尝试："
                echo "1. 检查网络连接"
                echo "2. 配置代理（取消脚本中的代理设置注释）"
                echo "3. 使用 VPN 或其他网络工具"
                exit 1
            fi
        fi
    fi
    
    # 配置 Windows 环境下的行尾符
    git config --global core.autocrlf true
    git config --global core.safecrlf false
else
    # Unix/Linux/MacOS 环境
    if ! ping -c 1 github.com > /dev/null 2>&1; then
        if ! curl -s https://github.com > /dev/null; then
            if ! wget -q --spider https://github.com; then
                echo "无法连接到 GitHub，请检查网络设置"
                exit 1
            fi
        fi
    fi
fi

# 检查 Git 配置
if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
    echo "检测到 Git 未配置用户信息，请配置："
    echo "请输入您的用户名："
    read git_username
    echo "请输入您的邮箱："
    read git_email
    
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    echo "Git 配置完成！"
fi

# 初始化 Git 仓库（如果还没初始化）
if [ ! -d .git ]; then
    git init
    echo "Git 仓库初始化完成！"
fi

# 创建 .gitignore 文件排除 .sh 文件和自身
echo "*.sh" > .gitignore
echo ".gitignore" >> .gitignore
echo "创建 .gitignore 文件，排除所有 .sh 文件和 .gitignore 文件"

# 检查是否已经存在远程仓库
if git remote | grep -q 'origin'; then
    echo "删除已存在的 origin..."
    git remote remove origin
fi

# 添加所有非 .sh 文件到暂存区
git add .

# 检查是否有文件要提交
if git status --porcelain | grep -q '^[MARCD]'; then
    # 提交更改
    echo "请输入提交信息:"
    read commit_message
    if [ -z "$commit_message" ]; then
        commit_message="Initial commit"
    fi
    git commit -m "$commit_message"
else
    echo "没有找到要提交的文件！请确保目录中有非 .sh 文件。"
    exit 1
fi

# 添加远程仓库
while true; do
    echo "请输入 GitHub 仓库 URL(SSH) (例如: git@github.com:leiteer/test2.git):"
    read repo_url
    if [ -n "$repo_url" ]; then
        git remote add origin "$repo_url"
        break
    else
        echo "URL 不能为空，请重新输入"
    fi
done

# 确保当前分支是 main
git branch -M main

# 尝试拉取远程仓库的更改
echo "正在检查远程仓库..."
if git ls-remote --exit-code origin &>/dev/null; then
    echo "远程仓库存在，正在同步更改..."
    # 设置自动合并提交信息
    git config --global core.mergeoptions "--no-edit"
    
    # 尝试合并前先保存本地文件的副本
    echo "备份本地文件..."
    for file in $(git ls-files); do
        if [ -f "$file" ]; then
            cp "$file" "${file}.backup"
        fi
    done
    
    # 尝试拉取和合并
    if ! git pull --no-rebase origin main; then
        if ! git -c core.editor=true pull --allow-unrelated-histories origin main; then
            echo "检测到文件冲突，正在处理..."
            
            # 使用本地版本
            echo "使用本地版本覆盖..."
            for file in $(git diff --name-only --diff-filter=U); do
                if [ -f "${file}.backup" ]; then
                    cp "${file}.backup" "$file"
                    git add "$file"
                fi
            done
            
            # 提交合并
            git commit -m "解决冲突：使用本地版本" || {
                echo "无法自动解决冲突，请手动处理以下文件："
                git diff --name-only --diff-filter=U
                # 清理备份文件
                find . -name "*.backup" -type f -delete
                exit 1
            }
        fi
    fi
    
    # 清理备份文件
    find . -name "*.backup" -type f -delete
fi

# 推送到 main 分支
echo "正在推送到远程仓库..."
git push origin main || {
    echo "推送失败，请尝试以下解决方案："
    echo "1. 检查 GitHub 仓库 URL 是否正确"
    echo "2. 检查是否有权限访问该仓库"
    echo "3. 如果遇到 SSL 问题，可以尝试："
    echo "   - 运行: git config --global http.sslVerify false"
    echo "   - 或使用 SSH 地址替代 HTTPS"
    echo "4. 确保已经配置了 GitHub 认证："
    echo "   - HTTPS: 需要配置个人访问令牌 (PAT)"
    echo "   - SSH: 需要配置 SSH 密钥"
    echo "5. 如果使用代理，请检查代理设置："
    echo "   - git config --global http.proxy http://proxyserver:port"
    exit 1
}

echo "成功上传到 GitHub！" 