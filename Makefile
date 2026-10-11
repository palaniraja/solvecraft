.PHONY: web start stop status web-start web-stop web-status web-setup

WEB_PID := $(CURDIR)/target/web.pid
WEB_LOG := $(CURDIR)/target/web.log
WEB_COMMAND := trunk serve --release --config $(CURDIR)/apps/solvecraft-web/Trunk.toml --open
WEB_RUNNING = test -n "$$pid" && ps -p "$$pid" -o command= | grep -F -- "$(WEB_COMMAND)" >/dev/null
WEB_READY = curl --silent --fail --max-time 2 --output /dev/null http://127.0.0.1:8781/

web: web-$(if $(filter start stop status,$(MAKECMDGOALS)),$(filter start stop status,$(MAKECMDGOALS)),start)
start: web-start
stop: web-stop
status: web-status

web-start: web-setup
	@mkdir -p "$(CURDIR)/target"; \
	pid=$$(cat "$(WEB_PID)" 2>/dev/null); \
	if ! $(WEB_RUNNING); then \
		nohup $(WEB_COMMAND) </dev/null >"$(WEB_LOG)" 2>&1 & \
		pid=$$!; printf '%s\n' "$$pid" >"$(WEB_PID)"; \
	fi; \
	printf 'Waiting for the web build (PID %s).\n' "$$pid"; \
	attempt=0; \
	while [ "$$attempt" -lt 30 ]; do \
		if ! $(WEB_RUNNING); then \
			rm -f "$(WEB_PID)"; printf 'Web server exited. Check %s\n' "$(WEB_LOG)"; exit 1; \
		fi; \
		if $(WEB_READY); then \
			printf 'Web server ready: http://127.0.0.1:8781\n'; exit 0; \
		fi; \
		sleep 1; attempt=$$((attempt + 1)); \
	done; \
	printf 'Still building in the background; not ready yet.\nRun make web status or follow the log: tail -f %s\n' "$(WEB_LOG)"

web-stop:
	@pid=$$(cat "$(WEB_PID)" 2>/dev/null); \
	if $(WEB_RUNNING); then \
		kill "$$pid" || exit 1; printf 'Web server stopped.\n'; \
	else \
		printf 'Web server is not running.\n'; \
	fi; \
	rm -f "$(WEB_PID)"

web-status:
	@pid=$$(cat "$(WEB_PID)" 2>/dev/null); \
	if $(WEB_RUNNING); then \
		if $(WEB_READY); then \
			printf 'Web server ready (PID %s): http://127.0.0.1:8781\n' "$$pid"; \
		else \
			printf 'Web process running (PID %s), but HTTP is not ready: building or startup error.\n' "$$pid"; \
		fi; \
		printf 'Log: %s\n' "$(WEB_LOG)"; \
	else \
		printf 'Web server is not running.\n'; \
	fi

web-setup:
	@command -v trunk >/dev/null 2>&1 || cargo install trunk --locked
	@rustup target add wasm32-unknown-unknown
