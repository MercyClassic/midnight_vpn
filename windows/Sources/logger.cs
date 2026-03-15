using System;
using System.Runtime.InteropServices;
using System.Text;

class LogProxy
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool SetCurrentConsoleFontEx(IntPtr consoleOutput, bool maximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);

    const int STD_OUTPUT_HANDLE = -11;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct COORD { public short X; public short Y; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX
    {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    static void SetFont(short size, string face)
    {
        try
        {
            var h = GetStdHandle(STD_OUTPUT_HANDLE);
            var cfi = new CONSOLE_FONT_INFO_EX();
            cfi.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFO_EX));
            cfi.FaceName = face;
            cfi.dwFontSize.X = 0;
            cfi.dwFontSize.Y = size;
            cfi.FontFamily = 54;
            cfi.FontWeight = 400;
            SetCurrentConsoleFontEx(h, false, ref cfi);
        }
        catch { }
    }

    static void Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.InputEncoding = Encoding.UTF8;
		Console.Title = "midnight logs";

		short fontSize = 14;
		string face = "Consolas";

		if (args.Length > 0) short.TryParse(args[0], out fontSize);
		if (args.Length > 1) face = args[1];

		SetFont(fontSize, face);

        string line;
        while ((line = Console.ReadLine()) != null)
        {
            Console.WriteLine(line);
        }
    }
}
