# Helm 项目常用命令封装
# 用法: make help

CHART      := .
HELM       ?= helm
RELEASE    ?= api

# 默认环境
ENV        ?= dev
NAMESPACE  ?= $(ENV)
VALUES     := environments/values-$(ENV).yaml

.PHONY: help
help: ## 显示帮助
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: lint
lint: ## 用三套 values 分别执行 helm lint
	@$(HELM) lint $(CHART)
	@for e in dev staging prod; do \
		echo "--- $$e ---"; \
		$(HELM) lint $(CHART) --values environments/values-$$e.yaml; \
	done

.PHONY: template
template: ## 渲染指定环境的清单: make template ENV=prod
	@$(HELM) template $(RELEASE) $(CHART) --values $(VALUES)

.PHONY: deploy
deploy: lint ## 部署到指定环境: make deploy ENV=prod NAMESPACE=prod
	@$(HELM) upgrade --install $(RELEASE) $(CHART) \
		--namespace $(NAMESPACE) --create-namespace \
		--values $(VALUES) --atomic --wait --timeout 5m --history-max 10

.PHONY: status
status: ## 查看 release 状态
	@$(HELM) status $(RELEASE) --namespace $(NAMESPACE)

.PHONY: history
history: ## 查看发布历史（回滚用）
	@$(HELM) history $(RELEASE) --namespace $(NAMESPACE) --max 10

.PHONY: rollback
rollback: ## 回滚到上一版本
	@$(HELM) rollback $(RELEASE) --namespace $(NAMESPACE)

.PHONY: test
test: ## 执行 helm test 冒烟测试
	@$(HELM) test $(RELEASE) --namespace $(NAMESPACE) --logs

.PHONY: uninstall
uninstall: ## 卸载 release
	@$(HELM) uninstall $(RELEASE) --namespace $(NAMESPACE) --wait

.PHONY: deps
deps: ## 拉取子 chart 依赖到 charts/
	@$(HELM) dependency update $(CHART)

.PHONY: package
package: deps ## 打包为 .tgz
	@mkdir -p dist
	@$(HELM) package $(CHART) --destination dist

.PHONY: clean
clean: ## 清理本地产物
	@rm -rf dist Chart.lock
