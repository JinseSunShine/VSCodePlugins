/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */
'use strict';

import Uri from 'vscode-uri'
import {
	IPCMessageReader, IPCMessageWriter,
	createConnection, IConnection, TextDocumentSyncKind,
	TextDocument, Diagnostic, DiagnosticSeverity, SignatureHelp, SignatureInformation, ParameterInformation,
	InitializeParams, InitializeResult, TextDocumentPositionParams, MarkedString, DocumentHighlight,
	CompletionItem, CompletionItemKind, Files, Definition, Location, Range, RenameParams,
	Position, SymbolInformation, SymbolKind, TextEdit, PublishDiagnosticsParams, WorkspaceEdit
} from 'vscode-languageserver';


// Create a connection for the server. The connection uses Node's IPC as a transport
let connection: IConnection = createConnection(new IPCMessageReader(process), new IPCMessageWriter(process));

let documents = new Map();

let fs = require("fs")
let path = require("path")

let CustomType_completion_array = new Array<CompletionItem>()
const CustomTypesDir = path.join(path.dirname(__dirname), "../lib/lua/CustomTypes");

function GatherCustomTypeCompletions() {
	CustomType_completion_array = new Array<CompletionItem>()

	for (let Item of fs.readdirSync(CustomTypesDir)) {
		let abs_path = path.join(CustomTypesDir, Item);
		let fs_state = fs.statSync(abs_path);
		if (fs_state.isFile() && Item.endsWith(".lua")) {
			let type_name = Item.substring(0, Item.length - 4)
			let item = CompletionItem.create(type_name)
			item.kind = CompletionItemKind.Class
			CustomType_completion_array.push(item)
		}
	}
}

GatherCustomTypeCompletions()

function ReRunLuaInspect()
{
	for(let [k, doc_item] of documents)
	{
		run_lua_inspect(doc_item)
	}
}

fs.watch(CustomTypesDir, (event, filename) => {
	if (event == 'rename') {
		GatherCustomTypeCompletions()
	}
	ReRunLuaInspect()
})

// After the server has started the client sends an initilize request. The server receives
// in the passed params the rootPath of the workspace plus the client capabilites. 
let workspaceRoot: string;
connection.onInitialize((params): InitializeResult => {
	workspaceRoot = params.rootPath;
	return {
		capabilities: {
			textDocumentSync: TextDocumentSyncKind.Full,
			definitionProvider: true,
			documentSymbolProvider: true,
			documentFormattingProvider: true,
			hoverProvider: true,
			documentRangeFormattingProvider: true,
			documentHighlightProvider: true,
			referencesProvider: true,
			renameProvider: true,
			completionProvider: {
				triggerCharacters: ['.', ':', '"', "'"]
			},
			"signatureHelpProvider": {
				"triggerCharacters": ['(', ',']
			}
		}
	}
});

// The content of a text document has changed. This event is emitted
// when the text document first opened or when its content has changed.
// documents.onDidChangeContent((change) => {
// 	validateTextDocument(change.document);
// });

// The settings interface describe the server relevant settings part
interface Settings {
	LuaInspect: LuaInspectSettings;
}

// These are the example settings we defined in the client's package.json
// file
interface LuaInspectSettings {
	ShowAllValues: boolean;
}

// hold the ShowAllValues setting
let ShowAllValues: boolean;

connection.onDidChangeConfiguration((change) => {
    let settings = <Settings>change.settings;
    ShowAllValues = settings.LuaInspect.ShowAllValues;
});

let MapFileInfo = new Map();
let MapFileFunc = new Map();
let MapFileReferences = new Map<string, Map<any, Array<Location>>>();
let MapFileHighlights = new Map<string, Map<any, Array<DocumentHighlight>>>();

let MapFileCompletions = new Map();
let MapFileSignatures = new Map();
let GlobalSignatures = new Map();
let MapFileToID_Value_Map = new Map();

function IsPosInRange(pos, range) {
	let line = pos.line
	let character = pos.character
	let start_pos = range.start
	let end_pos = range.end
	if (line < start_pos.line || line > end_pos.line) {
		return false;
	}
	if (line == start_pos.line && character < start_pos.character) {
		return false;
	}
	if (line == end_pos.line && character >= end_pos.character) {
		return false;
	}
	return true;
}

function GenerateSignature(id_name, signature_array) {
	let sig_info_array = new Array()

	for (let signature of signature_array) {
		let params = new Array<ParameterInformation>()
		let params_str = new Array<String>()
		let params_type = null
		if (Array.isArray(signature["Types"])) {
			params_type = signature["Types"]
		}
		if (Array.isArray(signature["Params"])) {
			for (let index = 0; index < signature["Params"].length; index++) {
				let param = signature["Params"][index]

				params.push(ParameterInformation.create(param))
				if (params_type) {
					let param_type = params_type[index]
					params_str.push(`${param_type} ${param}`)
				}
				else {
					params_str.push(param)
				}
			}
		}
		let strclass = signature["ClassName"]
		if (strclass == null) {
			strclass = ""
		}
		else {
			strclass += ":"
		}
		sig_info_array.push({
			label: `${strclass}${id_name}(${params_str.toString()})`,
			parameters: params
		})
	}

	return { signatures: sig_info_array, activeSignature: 0 }
}

const child_process = require('child_process');

let File_LuaInspect_Map = new Map()

let run_lua_inspect = function (document_item) {
	if (!File_LuaInspect_Map.has(document_item.uri)) {
		let the_doc = TextDocument.create(document_item.uri, document_item.languageId, document_item.version, document_item.text)
		var file_path = Files.uriToFilePath(the_doc.uri)
		const working_dir = path.join(path.dirname(__dirname), "../Tools");
		process.chdir(working_dir);

		connection.console.log(`run luainspect on file: ${file_path}\n`)
		const lua_inspect_ps = child_process.spawn('lua', ['lua-inspect/luainspect', file_path]);
		lua_inspect_ps.stdout.on('data', (data) => {
			let PS_Out_Err = File_LuaInspect_Map.get(document_item.uri)
			if (PS_Out_Err.Out == null)
			{
				PS_Out_Err.Out = ""
			}
			PS_Out_Err.Out += data.toString()	
		});

		lua_inspect_ps.stderr.on('data', (data) => {
			let PS_Out_Err = File_LuaInspect_Map.get(document_item.uri)
			if (PS_Out_Err.Err == null)
			{
				PS_Out_Err.Err = ""
			}
			PS_Out_Err.Err += data.toString()
		});

		lua_inspect_ps.on('close', (code) => {
			let PS_Out_Err = File_LuaInspect_Map.get(document_item.uri)
			if (code == 0)
			{
				Parse_Inspect_Result(document_item, PS_Out_Err.Out)
			}
			else
			{
				let error_msg = PS_Out_Err.Err
				connection.console.log(`stderr: ${error_msg}\n`);
				let error_json = JSON.parse(error_msg)
				if (error_json["ErrorType"] == "syntax") {
					let error_pos = Position.create(error_json["line"] - 1, error_json["colnum"] - 1)
					let id_range = Range.create(error_pos, error_pos)

					let diagnostics_array = new Array<Diagnostic>()
					diagnostics_array.push(Diagnostic.create(id_range, error_json["msg"], DiagnosticSeverity.Error))
					let diagnostics_param = {
						uri: document_item.uri,
						diagnostics: diagnostics_array
					}
					connection.sendDiagnostics(diagnostics_param)
				}
			}
			File_LuaInspect_Map.delete(document_item.uri)
		})

		File_LuaInspect_Map.set(document_item.uri, {PS:lua_inspect_ps})
	}
}

let Parse_Inspect_Result = function (document_item, inspect_result) {
	var map_range_info = new Map();
	MapFileInfo.set(document_item.uri, map_range_info);

	var func_array = new Array();
	MapFileFunc.set(document_item.uri, func_array);

	let map_loc_references = new Map<any, Array<Location>>()
	MapFileReferences.set(document_item.uri, map_loc_references)

	let map_loc_highlights = new Map<any, Array<DocumentHighlight>>()
	MapFileHighlights.set(document_item.uri, map_loc_highlights)

	let map_id_completions = new Map()
	MapFileCompletions.set(document_item.uri, map_id_completions)

	let map_id_signatures = new Map()
	MapFileSignatures.set(document_item.uri, map_id_signatures)

	let ID_Value_Map = new Map()
	MapFileToID_Value_Map.set(document_item.uri, ID_Value_Map)

	let the_doc = TextDocument.create(document_item.uri, document_item.languageId, document_item.version, document_item.text)

	let AddValueProperty = function (map_var, key_var, prop_name, prop_val) {
		if (!map_var.has(key_var)) {
			map_var.set(key_var, {})
		}
		let info_obj = map_var.get(key_var)
		info_obj[prop_name] = prop_val
	}

	let diagnostics_array = new Array<Diagnostic>()
	let diagnostics_param = {
		uri: document_item.uri,
		diagnostics: diagnostics_array
	}

	var range_lines = inspect_result.trim().split("\r\n");
	for (let index = 0; index < range_lines.length; index++) {
		if (range_lines[index].startsWith("{")) {
			let json_data = JSON.parse(range_lines[index])
			if (json_data != null) {
				let RequireCandidates = json_data["RequireCandidates"]
				if (RequireCandidates && Array.isArray(RequireCandidates)) {
					let completions = new Array<CompletionItem>()
					for (let require_name of RequireCandidates) {
						let item = CompletionItem.create(require_name)
						item.kind = CompletionItemKind.File
						completions.push(item)
					}
					map_id_completions.set("require", completions)
				}
				else if (json_data["ID_Value_Map"] && Array.isArray(json_data["ID_Value_Map"])) {
					for (let ID_Value of json_data["ID_Value_Map"]) {
						let all_completions = new Array<CompletionItem>()
						for (let name_type of ID_Value.Value) {
							let item = CompletionItem.create(name_type.Name)
							if (name_type.Type == "function") {
								item.kind = CompletionItemKind.Function
							}
							else {
								item.kind = CompletionItemKind.Field
							}
							all_completions.push(item)
						}

						map_id_completions.set(ID_Value.ID, all_completions)
					}
				}
				else if (json_data["ErrorType"] && json_data["ErrorType"] == "file") {
					let error_pos = Position.create(json_data["line"] - 1, json_data["colnum"] - 1)
					let id_range = Range.create(error_pos, error_pos)
					diagnostics_array.push(Diagnostic.create(id_range, json_data["msg"], DiagnosticSeverity.Error))
				}
				else if (json_data["GlobalCompletions"] && Array.isArray(json_data["GlobalCompletions"])) {
					for (let GlobalNameFields of json_data["GlobalCompletions"]) {
						if (Array.isArray(GlobalNameFields["Fields"])) {
							let completions = new Array<CompletionItem>()
							for (let field_name of GlobalNameFields["Fields"]) {
								let item = CompletionItem.create(field_name)
								item.kind = CompletionItemKind.File
								completions.push(item)
							}

							if (!map_id_completions.has(GlobalNameFields["Name"])) {
								map_id_completions.set(GlobalNameFields["Name"], completions)
							}
						}
					}
				}
				else if (json_data["GlobalSignatures"]) {
					for (let GlobalNameSignature of json_data["GlobalSignatures"]) {
						if (GlobalNameSignature["Name"] != null && GlobalNameSignature["Signature"]) {
							let func_name = GlobalNameSignature["Name"]
							GlobalSignatures.set(func_name, GenerateSignature(func_name, [GlobalNameSignature["Signature"]]))
						}
					}
				}
				else {
					let start_pos = Position.create(json_data["Line1"] - 1, json_data["Col1"] - 1)
					let start_offset = the_doc.offsetAt(start_pos)

					let end_pos = Position.create(json_data["Line2"] - 1, json_data["Col2"])
					let end_offset = the_doc.offsetAt(end_pos)
					let id_range = Range.create(start_pos, end_pos)

					let id_name = the_doc.getText().substring(start_offset, end_offset)

					if (json_data["RequirePath"] != null) {
						let def_pos = Position.create(0, 0)
						let file_path = json_data["RequirePath"]
						if (file_path == false) {
							diagnostics_array.push(Diagnostic.create(id_range, "File didn't exist", DiagnosticSeverity.Error))
						} else {
							let def_loc = Location.create(Uri.file(file_path).toString(), Range.create(def_pos, def_pos))
							AddValueProperty(map_range_info, id_range, "Definition", def_loc)
						}
					}

					let islocal = false
					if (json_data["Attributes"] != null) {
						let isUnused = false
						let isUnknown = false
						let isGlobal = false

						for (let attr of json_data["Attributes"]) {
							if (attr == "local") {
								islocal = true
							}
							else if (attr == "unused") {
								isUnused = true
							}
							else if (attr == "unknown") {
								isUnknown = true
							}
							else if (attr == "global") {
								isGlobal = true
							}
						}
						if (islocal && isUnused && id_name != "_") {
							diagnostics_array.push(Diagnostic.create(Range.create(start_pos, start_pos), "Unused local variable", DiagnosticSeverity.Warning))
						}
						if (isUnknown && isGlobal) {
							diagnostics_array.push(Diagnostic.create(Range.create(start_pos, start_pos), "Unknown global", DiagnosticSeverity.Error))
						}
					}

					if (json_data["id"] != null) {
						AddValueProperty(map_range_info, id_range, "ValueID", json_data["id"])
					}

					let isfunction = false
					let isdef = false
					if (json_data["ValueDesc"] != null) {
						for (let desc of json_data["ValueDesc"]) {
							let def_loc_info = desc["LocationDefined"]
							if (def_loc_info != null) {
								let file_path = def_loc_info["Path"]
								if (!path.isAbsolute(file_path)) {
									file_path = path.join(process.cwd(), file_path)
								}
								let def_pos = Position.create(def_loc_info["Line"] - 1, def_loc_info["Col"] - 1)
								let file_path_uri = Uri.file(file_path).toString()
								let def_loc = Location.create(file_path_uri, Range.create(def_pos, def_pos))
								AddValueProperty(map_range_info, id_range, "Definition", def_loc)
								if (def_pos.line == end_pos.line) {
									isdef = true
								}

								if (islocal) {
									let def_loc_info_str = JSON.stringify(def_loc_info)
									if (!map_loc_highlights.has(def_loc_info_str)) {
										map_loc_highlights.set(def_loc_info_str, new Array<DocumentHighlight>())
										map_loc_references.set(def_loc_info_str, new Array<Location>())
									}
									map_loc_highlights.get(def_loc_info_str).push(DocumentHighlight.create(id_range))
									map_loc_references.get(def_loc_info_str).push(Location.create(file_path_uri, id_range))
								}
							}

							if (desc["Type"] == "Hint") {
								if (desc["Value"] != null) {
									let VarValue = desc["Value"]
									isfunction = VarValue.startsWith("function")
									if (VarValue != "nil" && VarValue != "unknown") {
										AddValueProperty(map_range_info, id_range, "Value", VarValue)
									}
								}
							}
							else if (desc["Type"] == "Warning") {
								diagnostics_array.push(Diagnostic.create(id_range, desc["Value"], DiagnosticSeverity.Warning))
							}
							else if (desc["Type"] == "Error") {
								diagnostics_array.push(Diagnostic.create(id_range, desc["Value"], DiagnosticSeverity.Error))
							}
							else if (desc["Type"] == "Signature") {
								let func_prop = null
								if (desc["Value"]) {
									func_prop = [desc["Value"]]
								}
								if (func_prop != null) {
									if (!map_id_signatures.has(id_name)) {
										map_id_signatures.set(id_name, GenerateSignature(id_name, func_prop))
									}
									let sig_info = map_id_signatures.get(id_name)
									AddValueProperty(map_range_info, id_range, "Signature", sig_info.signatures)
								}
							}
						}
					}

					if (isfunction && isdef) {
						func_array.push(SymbolInformation.create(id_name, SymbolKind.Function, id_range, the_doc.uri))
					}
				}
			}
		}
	}

	connection.sendDiagnostics(diagnostics_param)
}
connection.onDidOpenTextDocument((params) => {
	documents.set(params.textDocument.uri, params.textDocument)
	run_lua_inspect(params.textDocument)
})
connection.onDidSaveTextDocument((params) => {
	if (documents.has(params.textDocument.uri)) {
		run_lua_inspect(documents.get(params.textDocument.uri))
	}
})
connection.onDidCloseTextDocument((params) => {
    if (documents.has(params.textDocument.uri)) {
		documents.delete(params.textDocument.uri)
	}
})

connection.onDidChangeTextDocument((params) => {
	if (documents.has(params.textDocument.uri)) {
		let the_doc_item = documents.get(params.textDocument.uri)
		the_doc_item.text = params.contentChanges[0].text
	}
});

let on_definition = function (params, token) {
	if (MapFileInfo.has(params.textDocument.uri)) {
		let map_range_info = MapFileInfo.get(params.textDocument.uri)
		for (var range_loc of map_range_info) {
			if (!IsPosInRange(params.position, range_loc[0])) {
				continue;
			}
			if (range_loc[1].Definition) {
				let def_loc = range_loc[1].Definition
				let file_path = Files.uriToFilePath(def_loc.uri)
				if (file_path.startsWith(workspaceRoot)) {
					return def_loc
				}
			}
		}
	}
}
connection.onDefinition(on_definition)

let on_hover = function (params, token) {
	if (MapFileInfo.has(params.textDocument.uri)) {
		let map_range_info = MapFileInfo.get(params.textDocument.uri)
		for (var range_loc of map_range_info) {
			if (!IsPosInRange(params.position, range_loc[0])) {
				continue;
			}
			let mark_strings = new Array<MarkedString>()
			if (range_loc[1].Definition) {
				let def_loc = range_loc[1].Definition
				let file_path = Files.uriToFilePath(def_loc.uri)
				if (file_path.startsWith(workspaceRoot)) {
					file_path = path.relative(workspaceRoot, file_path)
					mark_strings.push(MarkedString.fromPlainText(`Defined at ${file_path}`))
				}
			}
			if (range_loc[1].Signature) {
				if (!range_loc[1].Definition) {
					mark_strings.push(MarkedString.fromPlainText("Possible Signature:"))
				}
				for (let sig of range_loc[1].Signature) {
					mark_strings.push(MarkedString.fromPlainText(sig.label))
				}
			}
			else if (range_loc[1].Value) {
				mark_strings.push(MarkedString.fromPlainText(range_loc[1].Value))
			}
			return { contents: mark_strings };
		}
	}
}
connection.onHover(on_hover)

let on_DocumentSymbol = function (params, token) {
	if (MapFileFunc.has(params.textDocument.uri)) {
		return MapFileFunc.get(params.textDocument.uri)
	}
}
connection.onDocumentSymbol(on_DocumentSymbol)

let on_formatting = function (params, token) {
	let document_item = documents.get(params.textDocument.uri)
	let the_doc = TextDocument.create(document_item.uri, document_item.languageId, document_item.version, document_item.text)
	let the_content = the_doc.getText()

	let func_trim_split = function (the_str) {
		let trimed_str = the_str.trim()
		if (trimed_str.indexOf('\r\n') >= 0) {
			return trimed_str.split('\r\n');
		}
		else {
			return trimed_str.split('\n');
		}
	}

	let delimiter = 'unix'
	if (the_content.indexOf('\r\n') >= 0) {
		delimiter = 'windows'
	}
	let opt_obj = {
		input: the_content
	}
	var format_result = child_process.spawnSync('lua', ['Format.lua', '-s', '4'], opt_obj);
	if (format_result.status == 0) {
		let formatted_content = format_result.stdout.toString()
		let formatted_lines = func_trim_split(formatted_content);
		let orig_lines = func_trim_split(the_content)

		let text_edits = new Array();
		// if (orig_lines.length == formatted_lines.length) {
		// 	for (let line_index = 0; line_index < orig_lines.length; line_index++) {
		// 		if (orig_lines[line_index] != formatted_lines[line_index]) {
		// 			let line_range = Range.create(Position.create(line_index, 0), Position.create(line_index, orig_lines[line_index].length))
		// 			text_edits.push(TextEdit.replace(line_range, formatted_lines[line_index]));
		// 		}
		// 	}
		// }
		// else {

		let line_range = Range.create(Position.create(0, 0), the_doc.positionAt(the_content.length))
		text_edits.push(TextEdit.replace(line_range, formatted_content));
		// }
		return text_edits
	}
	else {
		connection.console.log(`stderr: ${format_result.stderr.toString()}\n`);
	}
}
connection.onDocumentFormatting(on_formatting)

connection.onDocumentRangeFormatting(on_formatting)

let func_oncompletion = function (params, token) {
	if (MapFileCompletions.has(params.textDocument.uri)) {
		if (documents.has(params.textDocument.uri)) {
			let document_item = documents.get(params.textDocument.uri)
			let the_doc = TextDocument.create(document_item.uri, document_item.languageId, document_item.version, document_item.text)
			let offset = the_doc.offsetAt(params.position)
			let the_substr = document_item.text.substr(0, offset)
			let id_name = null
			let seprator = null
			let id_position = null
			let matches = the_substr.match(/([\w]*)([.:])[\w]*$/)
			if (matches != null && matches.length == 3) {
				id_position = the_doc.positionAt(offset - matches[0].length)
				id_name = matches[1]
				seprator = matches[2]
			}
			else {
				matches = the_substr.match(/require[ (]*["'](\w*)$/)
				if (matches != null) {
					id_name = 'require'
				}
				else {
					matches = the_substr.match(/AnnotateType[ ]*\(["'](\w*)$/)
					if (matches != null) {
						return CustomType_completion_array
					}
				}
			}

			let map_id_completions = MapFileCompletions.get(params.textDocument.uri)
			if (id_position != null) {
				let ValueID = null
				if (MapFileInfo.has(params.textDocument.uri)) {
					let map_range_info = MapFileInfo.get(params.textDocument.uri)
					for (var range_loc of map_range_info) {
						if (!IsPosInRange(id_position, range_loc[0])) {
							continue;
						}

						if (range_loc[1].ValueID) {
							ValueID = range_loc[1].ValueID
							break
						}
					}
				}
				if (ValueID != null) {
					if (map_id_completions.has(ValueID)) {
						let completions = map_id_completions.get(ValueID)
						if (seprator == ":") {
							let func_completions = new Array<CompletionItem>()
							for (let completion of completions) {
								if (completion.kind == CompletionItemKind.Function) {
									func_completions.push(completion)
								}
							}
							return func_completions
						}
						return completions
					}
				}
			}
			else if (id_name != null) {
				if (map_id_completions.has(id_name)) {
					return map_id_completions.get(id_name)
				}
			}
		}
	}
}

connection.onCompletion(func_oncompletion)

let func_onsignature = function (params, token) {
	if (MapFileSignatures.has(params.textDocument.uri)) {
		if (documents.has(params.textDocument.uri)) {
			let document_item = documents.get(params.textDocument.uri)
			let the_doc = TextDocument.create(document_item.uri, document_item.languageId, document_item.version, document_item.text)
			let offset = the_doc.offsetAt(params.position)
			let right_paren_num = 0
			let param_index = 0
			for (let i = offset - 1; i >= 0; i--) {
				if (document_item.text[i] == '(') {
					if (right_paren_num == 0) {
						offset = i
						break
					}
					else {
						right_paren_num--;
					}
				}
				else if (document_item.text[i] == ')') {
					right_paren_num++;
				}
				else if (document_item.text[i] == ',' && right_paren_num == 0) {
					param_index++;
				}
			}

			let the_substr = document_item.text.substr(0, offset)

			let matches = the_substr.match(/([\w]*[\.]?([\w]*))$/)
			if (matches != null && matches.length >= 2) {
				for (let index = 1; index < matches.length; index++) {
					let id_name = matches[index]
					let map_id_signatures = MapFileSignatures.get(params.textDocument.uri)
					if (map_id_signatures.has(id_name)) {
						let signature_help = map_id_signatures.get(id_name)
						signature_help.activeParameter = param_index
						return signature_help
					}
					else if (GlobalSignatures.has(id_name)) {
						let signature_help = GlobalSignatures.get(id_name)
						signature_help.activeParameter = param_index
						return signature_help
					}
				}
			}

		}
	}
}

connection.onSignatureHelp(func_onsignature)

let func_onhighlight = function (params, token) {
	if (MapFileHighlights.has(params.textDocument.uri)) {
		let map_loc_highlights = MapFileHighlights.get(params.textDocument.uri)
		for (let refs of map_loc_highlights.values()) {
			for (let highlight of refs) {
				if (IsPosInRange(params.position, highlight.range)) {
					return refs
				}
			}
		}
	}
}
connection.onDocumentHighlight(func_onhighlight)

let func_onreferences = function (params, token) {
	if (MapFileReferences.has(params.textDocument.uri)) {
		let map_loc_references = MapFileReferences.get(params.textDocument.uri)
		for (let refs of map_loc_references.values()) {
			for (let ref of refs) {
				if (IsPosInRange(params.position, ref.range)) {
					return refs
				}
			}
		}
	}
}
connection.onReferences(func_onreferences)

let func_onrename = function (params: RenameParams, token) {
	let workspace_edit: WorkspaceEdit = { changes: {} }
	if (MapFileHighlights.has(params.textDocument.uri)) {
		let map_loc_highlights = MapFileHighlights.get(params.textDocument.uri)
		for (let refs of map_loc_highlights.values()) {
			let findit = false
			for (let highlight of refs) {
				if (IsPosInRange(params.position, highlight.range)) {
					findit = true
				}
			}
			if (findit) {
				let textedits = new Array<TextEdit>()
				for (let highlight of refs) {
					textedits.push(TextEdit.replace(highlight.range, params.newName))
				}
				workspace_edit.changes[params.textDocument.uri] = textedits
			}
		}
	}
	return workspace_edit
}
connection.onRenameRequest(func_onrename)
// Listen on the connection
connection.listen();