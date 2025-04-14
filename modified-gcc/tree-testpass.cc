#define INCLUDE_MEMORY
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
#include "tree.h"
#include "gimple.h"
#include "tree-pass.h"
#include "ssa.h"
#include "gimple-iterator.h"
#include "gimple-walk.h"
#include "internal-fn.h"
#include "gimple-pretty-print.h"
#include "tree-pretty-print.h"
#include "diagnostic.h"
#include "dumpfile.h"
#include "builtins.h"


namespace {
	const pass_data pass_data_testpass =
	{
		GIMPLE_PASS,
		"testpass",
		OPTGROUP_NONE,
		TV_NONE,
		PROP_cfg,
		0,
		0,
		0,
		0,
	};

	class pass_testpass : public gimple_opt_pass
	{
		public:
			pass_testpass (gcc::context *ctxt)
				: gimple_opt_pass (pass_data_testpass, ctxt)
			{}

			bool gate (function *) final override {
				return 1; // Always execute
			}
			unsigned int execute (function *) final override;

			void insert_signature(basic_block bb, bool is_start, tree& ptr_var, unsigned short signature, int bb_cnt);

			unsigned short generate_signature(function *fun, basic_block bb);
	};

	unsigned short pass_testpass::generate_signature(function *fun, basic_block bb) {
		const char *func_name = function_name(fun);
		unsigned int bb_index = bb->index;
		unsigned int hash = 5381;
	
		// Hash function using djb2 algorithm
		while (*func_name) {
			hash = ((hash << 5) + hash) + *func_name++; // hash * 33 + c
		}
		hash ^= bb_index; // Combine with basic block index
	
		return (unsigned short) hash;
	}

	// Helper function to create the signature store instruction
	void pass_testpass::insert_signature(basic_block bb, bool is_start, tree& ptr_var, unsigned short signature, int bb_cnt) {

		// tree addr = build_int_cst(ptr_type_node, 0x1000); //store to memory address 0x1000 (will replace with actual MMIO register's address)
		tree value = build_int_cst(integer_type_node, signature); //store the signature
		//tree ptr_var = create_tmp_var(ptr_type_node, "ptr_tmp");
		//tree ptr_var = create_tmp_reg(ptr_type_node, "ptr_tmp");
		// gimple *ptr_assign = gimple_build_assign(ptr_var, addr);


		tree mem_ref = build2(MEM_REF, integer_type_node, ptr_var, build_int_cst(ptr_type_node, 0));
		gimple *store_stmt = gimple_build_assign(mem_ref, value);



		//gimple_stmt_iterator gsi_start = gsi_start_bb(bb);
		gimple_stmt_iterator gsi_start = gsi_after_labels(bb); //need to insert at start of block after labels since labels are crucial for control flow and shouldn't be disrupted
		
		//TODO: NOT SURE IF I NEED; GSI_AFTER_LABELS ABOVE MIGHT BE ENOUGH//
		while (!gsi_end_p(gsi_start) &&
       		(gimple_code(gsi_stmt(gsi_start)) == GIMPLE_DEBUG ||
			gimple_code(gsi_stmt(gsi_start)) == GIMPLE_LABEL)) {
			// gimple_code(gsi_stmt(gsi_start)) == GIMPLE_COND ||
			// gimple_code(gsi_stmt(gsi_start)) == GIMPLE_SWITCH)) {

    		gsi_next(&gsi_start);
		}
		
		gimple_stmt_iterator gsi_end = gsi_last_bb(bb);

		//TODO: IDK IF I NEED 
		// while (!gsi_end_p(gsi_end) &&
		// 	(gimple_code(gsi_stmt(gsi_end)) == GIMPLE_DEBUG ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_LABEL ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_RETURN ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_COND ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_SWITCH ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_GOTO ||
		// 	gimple_code(gsi_stmt(gsi_end)) == GIMPLE_CALL)) { //need to insert before GIMPLE_CALL since should do bb exit signature before making the function call (the function call is the single exit point of bb)
    		
		// 	gsi_prev(&gsi_end);
		// }

		gimple_stmt_iterator it = gsi_end;
		bool is_goto = false;
		while (!gsi_end_p(it)) {
			if (
				gimple_code(gsi_stmt(it)) == GIMPLE_RETURN ||
				gimple_code(gsi_stmt(it)) == GIMPLE_COND ||
				gimple_code(gsi_stmt(it)) == GIMPLE_SWITCH ||
				gimple_code(gsi_stmt(it)) == GIMPLE_GOTO ||
				gimple_code(gsi_stmt(it)) == GIMPLE_CALL) { //need to insert before GIMPLE_CALL since should do bb exit signature before making the function call (the function call is the single exit point of bb)
					// if (gimple_code(gsi_stmt(it)) == GIMPLE_GOTO) {
					// 	is_goto = true;
					// }
					// bool is_call_or_ret = gimple_code(gsi_stmt(it)) == GIMPLE_CALL || gimple_code(gsi_stmt(it)) == GIMPLE_RETURN ? 1 : 0;


					gsi_prev(&it);
					gsi_end = it;
					// if (is_goto) {
					// 	gsi_end = it;
					// 	continue;
					// }

					// if (is_call_or_ret ) {
					// 	gsi_end = it;
					// }
					continue;

			}

			gsi_prev(&it);
		}

		// Insert the statement
		if (is_start) {
			if (bb_cnt == 1) { //move pointer by one to account for ptr_temp=address assignment in first bb of function
				gsi_next(&gsi_start);
			}
			gsi_insert_before(&gsi_start, store_stmt, GSI_NEW_STMT); //this statement will actually be second
			//gsi_insert_before(&gsi_start, ptr_assign, GSI_NEW_STMT); //this statement will be first
		} else {
			//gsi_insert_after(&gsi_end, ptr_assign, GSI_NEW_STMT); //this statement will be first
			gsi_insert_after(&gsi_end, store_stmt, GSI_NEW_STMT); //this statement will actually be second
			// gsi_insert_before(&gsi_end, ptr_assign, GSI_NEW_STMT);
    		// gsi_insert_before(&gsi_end, memset_call, GSI_NEW_STMT);
		}
		todo_flags_finish = todo_flags_finish | TODO_update_ssa; //need to update todo_flags of gimple_opt_pass so it can call update_ssa to make changes (only required if updating SSA form, whcih i am doing with gsi_insert_before)
	}

	unsigned int pass_testpass::execute(function *fun) {
		basic_block bb;
		int bb_cnt = 0, stmt_cnt = 0;

		tree ptr_var = create_tmp_reg(ptr_type_node, "ptr_tmp");
		tree addr = build_int_cst(ptr_type_node, 0x1000); //store to memory address 0x1000 (will replace with actual MMIO register's address)
		gimple *ptr_assign = gimple_build_assign(ptr_var, addr);

		basic_block entry_bb = ENTRY_BLOCK_PTR_FOR_FN(fun)->next_bb;
		gimple_stmt_iterator gsi = gsi_after_labels(entry_bb);
		gsi_insert_before(&gsi, ptr_assign, GSI_NEW_STMT);

		FOR_EACH_BB_FN(bb, fun) {
			bb_cnt++;
			unsigned short signature = generate_signature(DECL_STRUCT_FUNCTION(current_function_decl), bb);
			insert_signature(bb, true, ptr_var, signature, bb_cnt);  //insert signature at the beginning
			insert_signature(bb, false, ptr_var, signature, bb_cnt); //insert signature at the end

			// if (dump_file) {
			// 	fprintf(dump_file, "===== Basic block %d =====\n", bb_cnt);
			// 	for (gimple_stmt_iterator gsi = gsi_start_bb(bb); !gsi_end_p(gsi); gsi_next(&gsi)) {
			// 		gimple *g = gsi_stmt(gsi);
			// 		stmt_cnt++;
			// 		fprintf(dump_file, "----- Statement %d -----\n", stmt_cnt);
			// 		print_gimple_stmt(dump_file, g, 0, TDF_VOPS | TDF_MEMSYMS);
			// 	}
			// }
		}

		// if (dump_file) {
		// 	fprintf(dump_file, "------------------------------------\n");
		// 	fprintf(dump_file, "Total Basic Blocks: %d\n", bb_cnt);
		// 	fprintf(dump_file, "Total Gimple Statements: %d\n", stmt_cnt);
		// 	fprintf(dump_file, "------------------------------------\n\n");
		// }

		return 0;
	}
}

gimple_opt_pass *
make_pass_testpass (gcc::context *ctxt)
{
	return new pass_testpass(ctxt);
}
