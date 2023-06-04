test_all:
	@echo "Run unit tests..."
	nvim --headless --noplugin -u tests/minimal_init.vim  -c "PlenaryBustedDirectory tests  { minimal_init = './tests/minimal_init.vim' }"
	@echo

test_ot:
	@echo "Run unit tests..."
	nvim --headless --noplugin -u tests/minimal_init.vim  -c "PlenaryBustedFile tests/operational_transformation_spec.lua"
	@echo

test_messages:
	@echo "Run unit tests..."
	nvim --headless --noplugin -u tests/minimal_init.vim  -c "PlenaryBustedFile tests/edit_message_spec.lua"
	@echo