'use strict';
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {

    // Use the console to output diagnostic information (console.log) and errors (console.error)
    // This line of code will only be executed once when your extension is activated
    console.log('Congratulations, your extension "openwithvim" is now active!');

    // The command has been defined in the package.json file
    // Now provide the implementation of the command with  registerCommand
    // The commandId parameter must match the command field in package.json
    let disposable = vscode.commands.registerCommand('extension.OpenWithVim', (param) => {
        console.log(param.fsPath)
        const spawn = require('child_process').spawn;
        const bat = spawn('C:\\Windows\\gvim.bat', [param.fsPath]);
    });
    context.subscriptions.push(disposable);

    let disposable_OpenAllLuaScripts = vscode.commands.registerCommand('extension.OpenAllLuaScripts', (param) => {
        let allfiles = vscode.workspace.findFiles("**/*.lua", "")
        allfiles.then(
            (result: vscode.Uri[]) => {
                result.forEach(function (value, index, array) {
                    vscode.workspace.openTextDocument(value);
                })
            }
        )
    });

    context.subscriptions.push(disposable_OpenAllLuaScripts);
}

// this method is called when your extension is deactivated
export function deactivate() {
}