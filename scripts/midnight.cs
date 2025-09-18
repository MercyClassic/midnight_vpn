using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using System.Security.Principal;


class SingboxTrayApp : ApplicationContext
{
    private NotifyIcon notifyIcon;
    private Process singboxProcess;
    private Process logViewerProcess;
    private StreamWriter logWriter;
    private ToolStripMenuItem logMenuItem;
    private ToolStripMenuItem vpnMenuItem;
	private string appDir;

    private StringBuilder buffer = new StringBuilder();
    private readonly object bufferLock = new object();
    private const int MAX_BUFFER_CHARS = 20000;

    [DllImport("user32.dll")]
    private static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    public SingboxTrayApp()
    {
        appDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "core");
        string exePath = Path.Combine(appDir, "sing-box.exe");
        string configPath = Path.Combine(appDir, "config.json");

        StartSingbox(exePath, appDir, configPath);

        ContextMenuStrip menu = new ContextMenuStrip();

        logMenuItem = new ToolStripMenuItem("Show logs");
        logMenuItem.Click += (s, e) => ToggleLogs();
        menu.Items.Add(logMenuItem);

        vpnMenuItem = new ToolStripMenuItem("Disable VPN");
        vpnMenuItem.Click += (s, e) => ToggleVpn(exePath, appDir, configPath);
        menu.Items.Add(vpnMenuItem);

		ToolStripMenuItem editConfigItem = new ToolStripMenuItem("Edit config");
		editConfigItem.Click += (s, e) => EditConfig(configPath);
		menu.Items.Add(editConfigItem);

		menu.Items.Add(new ToolStripSeparator());

        ToolStripMenuItem exitItem = new ToolStripMenuItem("Exit");
        exitItem.Click += (s, e) => ExitApp();
        menu.Items.Add(exitItem);

        notifyIcon = new NotifyIcon();
        string iconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "icons", "gear.ico");
        notifyIcon.Icon = File.Exists(iconPath) ? new Icon(iconPath) : SystemIcons.Application;
        notifyIcon.Text = "sing-box";
        notifyIcon.ContextMenuStrip = menu;
        notifyIcon.Visible = true;

        Application.ApplicationExit += (s, e) => { notifyIcon.Visible = false; };
    }

    private void StartSingbox(string exePath, string appDir, string configPath)
    {
        if (singboxProcess != null && !singboxProcess.HasExited) return;

        singboxProcess = new Process();
        singboxProcess.StartInfo.FileName = exePath;
        singboxProcess.StartInfo.Arguments = "run -c \"" + configPath + "\"";
        singboxProcess.StartInfo.WorkingDirectory = appDir;
        singboxProcess.StartInfo.UseShellExecute = false;
        singboxProcess.StartInfo.RedirectStandardOutput = true;
        singboxProcess.StartInfo.RedirectStandardError = true;
        singboxProcess.StartInfo.StandardOutputEncoding = Encoding.UTF8;
        singboxProcess.StartInfo.StandardErrorEncoding = Encoding.UTF8;
        singboxProcess.StartInfo.CreateNoWindow = true;

        singboxProcess.OutputDataReceived += (s, e) => OnSingboxLine(e.Data);
        singboxProcess.ErrorDataReceived += (s, e) => OnSingboxLine(e.Data);

        singboxProcess.Start();
        singboxProcess.BeginOutputReadLine();
        singboxProcess.BeginErrorReadLine();
    }

    private void StopSingbox()
    {
        try { if (singboxProcess != null && !singboxProcess.HasExited) singboxProcess.Kill(); } catch { }
        singboxProcess = null;
    }

    private void OnSingboxLine(string line)
    {
        if (string.IsNullOrEmpty(line)) return;

        lock (bufferLock)
        {
            buffer.AppendLine(line);
            if (buffer.Length > MAX_BUFFER_CHARS)
                buffer.Remove(0, buffer.Length - (MAX_BUFFER_CHARS / 2));

            if (logWriter != null)
            {
                try { logWriter.WriteLine(line); logWriter.Flush(); } catch { }
            }
        }
    }

    private void ToggleLogs()
    {
        if (logViewerProcess == null || logViewerProcess.HasExited)
        {
			logViewerProcess = new Process();
			logViewerProcess.StartInfo.FileName = Path.Combine(appDir, "logger.exe");
			logViewerProcess.StartInfo.Arguments = "16 Consolas";
			logViewerProcess.StartInfo.UseShellExecute = false;
			logViewerProcess.StartInfo.RedirectStandardInput = true;
			logViewerProcess.StartInfo.CreateNoWindow = false;
			logViewerProcess.EnableRaisingEvents = true;


            logViewerProcess.Exited += (s, e) =>
            {
                logMenuItem.Text = "Show logs";
                lock (bufferLock) { logWriter = null; }
                logViewerProcess = null;
            };

            logViewerProcess.Start();
            System.Threading.Thread.Sleep(300);

            MoveWindow(logViewerProcess.MainWindowHandle, 100, 100, 900, 500, true);

            lock (bufferLock)
            {
                logWriter = logViewerProcess.StandardInput;
                if (buffer.Length > 0)
                {
                    try { logWriter.Write(buffer.ToString()); logWriter.Flush(); } catch { }
                }
            }

            logMenuItem.Text = "Hide logs";
        }
        else
        {
            try { if (logWriter != null) logWriter.Close(); } catch { }
            try { if (!logViewerProcess.HasExited) logViewerProcess.Kill(); } catch { }
            logViewerProcess = null;
            logWriter = null;
            logMenuItem.Text = "Show logs";
        }
    }
	
	private void EditConfig(string configPath)
	{
		try
		{
			string notepadpp = @"C:\Apps\Notepad++\notepad++.exe";

			if (File.Exists(notepadpp))
			{
				Process.Start(notepadpp, "\"" + configPath + "\"");
			}
			else
			{
				Process.Start("notepad.exe", "\"" + configPath + "\"");
			}
		}
		catch (Exception ex)
		{
			MessageBox.Show("Не удалось открыть config.json:\n" + ex.Message,
							"Ошибка", MessageBoxButtons.OK, MessageBoxIcon.Error);
		}
	}

    private void ToggleVpn(string exePath, string appDir, string configPath)
    {
        if (singboxProcess == null || singboxProcess.HasExited)
        {
            StartSingbox(exePath, appDir, configPath);
            vpnMenuItem.Text = "Disable VPN";
        }
        else
        {
            StopSingbox();
            vpnMenuItem.Text = "Enable VPN";
        }
    }

    private void ExitApp()
    {
        StopSingbox();
        try { if (logViewerProcess != null && !logViewerProcess.HasExited) logViewerProcess.Kill(); } catch { }
        notifyIcon.Visible = false;
        Application.Exit();
    }

	private static bool IsRunAsAdmin()
    {
        WindowsIdentity id = WindowsIdentity.GetCurrent();
        WindowsPrincipal principal = new WindowsPrincipal(id);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

	private static void RestartAsAdmin()
    {
        string exePath = Application.ExecutablePath;
        ProcessStartInfo psi = new ProcessStartInfo(exePath);
        psi.UseShellExecute = true;
        psi.Verb = "runas";
        try { Process.Start(psi); } catch { }
    }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
		
		if (!IsRunAsAdmin())
        {
            DialogResult result = MessageBox.Show(
                "Приложение запущено без прав администратора.\n\n" +
                "sing-box может не поднять TUN-интерфейс.\n\n" +
                "Хотите перезапустить с правами администратора?",
                "Недостаточно прав",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning);

            if (result == DialogResult.Yes)
            {
                RestartAsAdmin();
            }
            return;
        }
		
        Application.Run(new SingboxTrayApp());
    }
}
