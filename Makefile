.PHONY: web start stop status release debug web-start web-stop web-status web-setup

WEB_PID := $(CURDIR)/target/web.pid
WEB_LOG := $(CURDIR)/target/web.log
WEB_MODE := $(if $(filter debug,$(MAKECMDGOALS)),debug,release)
WEB_COMMAND := trunk serve --release=$(if $(filter release,$(WEB_MODE)),true,false) --config $(CURDIR)/apps/solvecraft-web/Trunk.toml --open
WEB_RUNNING = (case "$$pid" in ''|*[!0-9]*|0) false ;; *) ps -p "$$pid" -o command= 2>/dev/null | grep -F -- "--config $(CURDIR)/apps/solvecraft-web/Trunk.toml --open" >/dev/null ;; esac)

ifneq ($(words $(filter release debug,$(MAKECMDGOALS))),$(if $(filter release debug,$(MAKECMDGOALS)),1,0))
$(error Choose either release or debug, not both)
endif
WEB_READY = curl --silent --fail --max-time 2 --output /dev/null http://127.0.0.1:8781/

web: web-$(if $(filter start stop status,$(MAKECMDGOALS)),$(filter start stop status,$(MAKECMDGOALS)),start)
start: web-start
stop: web-stop
status: web-status
release debug:
	@:

web-start: web-setup
	@mkdir -p "$(CURDIR)/target"; \
	pid=$$(cat "$(WEB_PID)" 2>/dev/null); \
	if $(WEB_RUNNING) && ! ps -p "$$pid" -o command= | grep -F -- "$(WEB_COMMAND)" >/dev/null; then \
		printf 'Web server is already running in another mode. Run make web stop first.\n'; exit 1; \
	fi; \
	if ! $(WEB_RUNNING); then \
		RUST_LOG=info,trunk=debug nohup $(WEB_COMMAND) </dev/null >"$(WEB_LOG)" 2>&1 & \
		pid=$$!; printf '%s\n' "$$pid" >"$(WEB_PID)"; \
	fi; \
	printf 'Waiting for the %s web build (PID %s). Log: %s\n' "$(WEB_MODE)" "$$pid" "$(WEB_LOG)"; \
	tail -n 20 -f "$(WEB_LOG)" & log_pid=$$!; \
	trap 'kill "$$log_pid" 2>/dev/null || true' 0; \
	trap 'exit 130' INT; trap 'exit 143' TERM; \
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
