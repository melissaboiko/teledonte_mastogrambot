bot: *.nim
	nim c -d:ssl bot.nim

.PHONY: run
run:
	./bot

.PHONY: debug
debug: bot.nim
	nim c --linedir:on --debuginfo --stacktrace:on bot.nim

.PHONY: clean
clean:
	rm -f bot

.PHONY: distclean
distclean: clean
