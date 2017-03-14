/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

'use strict';

import {
	DebugSession,
	InitializedEvent, TerminatedEvent, ContinuedEvent, StoppedEvent, BreakpointEvent, OutputEvent, Event,
	Thread, StackFrame, Scope, Source, Handles, Breakpoint
} from 'vscode-debugadapter';
import { DebugProtocol } from 'vscode-debugprotocol';
import { readFileSync } from 'fs';
import { basename } from 'path';


/**
 * This interface should always match the schema found in the mock-debug extension manifest.
 */
export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {
	/** An absolute path of the project to debug. */
	projectDir: string;
	clientIndex: string;
}

class MockDebugSession extends DebugSession {

	// we don't support multiple threads, so we can use a hardcoded ID for the default thread
	private static THREAD_ID = 1;

	// since we want to send breakpoint events, we will assign an id to every event
	// so that the frontend can match events with breakpoints.
	private _breakpointId = 1000;

	// This is the next line that will be 'executed'
	private __currentLine = 0;
	private get _currentLine(): number {
		return this.__currentLine;
	}
	private set _currentLine(line: number) {
		this.__currentLine = line;
		this.sendEvent(new OutputEvent(`line: ${line}\n`));	// print current line on debug console
	}

	// the initial (and one and only) file we are 'debugging'
	private _sourceFile: string;

	// maps from sourceFile to array of Breakpoints
	private _breakPoints = new Map<string, DebugProtocol.Breakpoint[]>();

	private _variableHandles = new Handles<string>();

	private _timer;

	private mobdebugger;

	private breakpoints_need_update = false;

	private debugger_ready = false;

	private script_path_map = new Map();

	private cur_stack_frames = null;

	private eval_response_map = new Map();

	private command_list = new Array();


	/**
	 * Creates a new debug adapter that is used for one debug session.
	 * We configure the default implementation of a debug adapter here.
	 */
	public constructor() {
		super();

		// this debugger uses zero-based lines and columns
		this.setDebuggerLinesStartAt1(false);
		this.setDebuggerColumnsStartAt1(false);
	}

	protected clearCache(): void {
		this.cur_stack_frames = null;
	}
	/**
	 * The 'initialize' request is the first request called by the frontend
	 * to interrogate the features the debug adapter provides.
	 */
	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		// since this debug adapter can accept configuration requests like 'setBreakpoint' at any time,
		// we request them early by sending an 'initializeRequest' to the frontend.
		// The frontend will end the configuration sequence by calling 'configurationDone' request.
		this.sendEvent(new InitializedEvent());

		// This debug adapter implements the configurationDoneRequest.
		response.body.supportsConfigurationDoneRequest = true;

		// make VS Code to use 'evaluate' when hovering over source
		response.body.supportsEvaluateForHovers = true;

		// make VS Code to show a 'step back' button
		response.body.supportsStepBack = true;

		this.sendResponse(response);
	}

	protected executeCommand(szCommand) {
		const path = require('path');
		const assert = require('assert');
		assert(this.debugger_ready, 'executeCommand ${szCommand} when debugger_ready is false');
		if (szCommand == "updatebreakpoints") {
			this.mobdebugger.stdin.write(`delallb\n`);
			console.log("cmd:delallb\n");
			let bp_commands = new Array();
			for (var path_str of this._breakPoints.keys()) {
				for (var bp of this._breakPoints.get(path_str)) {
					bp.verified = true
					var script_path = path.basename(path_str);
					bp_commands.push(`setb ${script_path} ${bp.line}\n`);
					this.sendEvent(new BreakpointEvent("update", bp));
				}
			}
			this.command_list = bp_commands.concat(this.command_list);
		}
		else {
			this.mobdebugger.stdin.write(szCommand);
			console.log(`cmd:${szCommand}\n`);
		}
		this.debugger_ready = false;
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		const path = require('path');
		const fs = require("fs");

		var scan_dir = function (cur_dir, path_map) {
			for (let Item of fs.readdirSync(cur_dir)) {
				let abs_path = path.join(cur_dir, Item);
				let fs_state = fs.statSync(abs_path);
				if (fs_state.isFile() && Item.endsWith(".lua")) {
					if (path_map.has(Item)) {
						this.sendEvent(new OutputEvent(`Duplicated file named \"${Item}\"`));
					} else {
						path_map.set(Item, abs_path);
					}
				}
				else if (fs_state.isDirectory()) {
					scan_dir.call(this, abs_path, path_map);
				}
			}
		}
		scan_dir.call(this, args.projectDir, this.script_path_map);

		const working_dir = path.join(path.dirname(__dirname), "Tools");
		process.chdir(working_dir);

		const log_stream = require('fs').createWriteStream("SimpleLua.log");
		const util = require('util');
		console.log = function (d) { //
			log_stream.write(util.format(d) + '\n');
		};

		this.continueRequest(<DebugProtocol.ContinueResponse>response, { threadId: MockDebugSession.THREAD_ID });

		const spawn = require('child_process').spawn;
		this.mobdebugger = spawn('lua', ['Main.lua', args.clientIndex]);

		var on_stdout = function (data) {
			console.log(`stdout: ${data}`);
			var data_str = data.toString();

			if (data_str.startsWith("Type ")) {
				this.debugger_ready = true;
				this.clearCache();
				this.command_list = new Array();
				this.command_list.push("updatebreakpoints");
				this.command_list.push("run\n");
				this.sendEvent(new OutputEvent(`Client Connected`));
			}
			else if (data_str.startsWith("Program finished")) {
				this.sendEvent(new TerminatedEvent());
				this.clearCache();
				this.command_list = new Array();
			}

			else if (data_str.startsWith("{")) {
				let Json_Data = JSON.parse(data_str)
				if (Json_Data["MsgType"] == "Eval") {
					var eval_result = Json_Data["Value"];
					if (eval_result == "") {
						eval_result = "not available";
					}
					if (this.eval_response_map.has(Json_Data["Exp"])) {
						var response = this.eval_response_map.get(Json_Data["Exp"]);
						response.body = { result: eval_result, variablesReference: 0 };
						this.sendResponse(response);
						this.eval_response_map.delete(Json_Data["Exp"])
					}
					this.debugger_ready = true;
				}
				else if (Json_Data["MsgType"] == "Paused") {
					this._currentLine = this.convertClientLineToDebugger(Number.parseInt(Json_Data["Line"]));
					this.mobdebugger.stdin.write(`stack\n`);
				}
				else if (Json_Data["MsgType"] == "Stack") {
					this.cur_stack_frames = new Array<StackFrame>();
					let index = 0
					for (let frame of Json_Data["Frames"]) {
						this.cur_stack_frames.push(new StackFrame(index, `${frame[0]}(${index})`, new Source(frame[1],
							this.script_path_map.get(frame[1])),
							frame[3], 0));
						index++;
					}
					this.sendEvent(new StoppedEvent("breakpoint", MockDebugSession.THREAD_ID));
					this.debugger_ready = true;
				}
			}
			else if (data_str.startsWith("setb") || data_str.startsWith("delallb") || data_str.startsWith("Invalid")) {
				this.debugger_ready = true;
			}

			if (this.debugger_ready == true && this.command_list.length > 0) {
				this.executeCommand(this.command_list.shift());
			}
		};

		this.mobdebugger.stdout.on('data', on_stdout.bind(this));
		this.mobdebugger.stderr.on('data', (data) => {
			console.log(`stderr: ${data}`);
		});

		this.mobdebugger.on('close', (code) => {
			console.log(`child process exited with code ${code}`);
		});

		this.mobdebugger.on('error', (err) => {
			console.log('Failed to start lua.');
		});

	}

	protected disconnectRequest(response: DebugProtocol.DisconnectResponse, args: DebugProtocol.DisconnectArguments): void {
		// stop sending custom events
		clearInterval(this._timer);
		if (this.debugger_ready) {
			this.executeCommand("done\nexit\n");
		}
		else {
			this.command_list.push("done\nexit\n");
		}
		this.clearCache();
		super.disconnectRequest(response, args);
	}

	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		var path = args.source.path;
		var clientLines = args.lines;

		var breakpoints = new Array<Breakpoint>();

		// verify breakpoint locations
		for (var i = 0; i < clientLines.length; i++) {
			const bp = <DebugProtocol.Breakpoint>new Breakpoint(false, clientLines[i]);
			bp.id = this._breakpointId++;
			breakpoints.push(bp);
		}
		this._breakPoints.set(path, breakpoints);
		// send back the actual breakpoint positions
		response.body = {
			breakpoints: breakpoints
		};
		this.sendResponse(response);
		if (this.debugger_ready) {
			this.executeCommand("updatebreakpoints");
		}
		else {
			for (let szCommand of this.command_list) {
				if (szCommand == "updatebreakpoints") {
					return;
				}
			}
			this.command_list.push("updatebreakpoints");
		}
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		// return the default thread
		response.body = {
			threads: [
				new Thread(MockDebugSession.THREAD_ID, "thread 1")
			]
		};
		this.sendResponse(response);
	}

	/**
	 * Returns a fake 'stacktrace' where every 'stackframe' is a word from the current line.
	 */
	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		if (this.debugger_ready && this.cur_stack_frames != null) {
			response.body = {
				stackFrames: this.cur_stack_frames,
				totalFrames: this.cur_stack_frames.length
			};
		}
		this.sendResponse(response);
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		if (this.debugger_ready) {
			this.clearCache();
			this.executeCommand("run\n");
		}
		this.sendResponse(response);
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		if (this.debugger_ready) {
			this.clearCache();
			this.executeCommand("over\n");
		}
		this.sendResponse(response);
	}

	protected stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): void {
		if (this.debugger_ready) {
			this.clearCache();
			this.executeCommand("step\n");
		}
		this.sendResponse(response);
	}

	protected stepOutRequest(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments): void {
		if (this.debugger_ready) {
			this.clearCache();
			this.executeCommand("out\n");
		}
		this.sendResponse(response);
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		this.eval_response_map.set(args.expression, response);
		let cmd_str = `eval ${args.expression}\n`
		if (this.debugger_ready) {
			this.executeCommand(cmd_str);
		}
	}
}

DebugSession.run(MockDebugSession);
