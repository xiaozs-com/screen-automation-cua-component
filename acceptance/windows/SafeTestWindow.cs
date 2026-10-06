using System;
using System.Drawing;
using System.Windows.Forms;

namespace ScreenAutomationCuaAcceptance {
    internal sealed class SafeTestWindow : Form {
        private const int WS_EX_NOACTIVATE = 0x08000000;
        private readonly Label status;
        private readonly TextBox input;
        private int clicks;

        internal SafeTestWindow() {
            Text = "Screen Automation Cua Safe Test Window";
            Name = "ScreenAutomationCuaSafeTestWindow";
            ClientSize = new Size(520, 240);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;

            var notice = new Label { Left = 24, Top = 20, Width = 470, Height = 38,
                Text = "专用无敏感内容验收窗口。不会发送、删除、支付或发布任何内容。" };
            input = new TextBox { Left = 24, Top = 72, Width = 470, Name = "safeInput",
                AccessibleName = "Safe test input" };
            var button = new Button { Left = 24, Top = 116, Width = 180, Height = 36,
                Text = "Background test click", Name = "safeButton", AccessibleName = "Safe test button" };
            status = new Label { Left = 24, Top = 172, Width = 470, Height = 28,
                Text = "clicks=0", Name = "status" };
            button.Click += delegate { clicks++; status.Text = "clicks=" + clicks + "; text=" + input.Text; };
            Controls.AddRange(new Control[] { notice, input, button, status });
        }

        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams {
            get {
                CreateParams parameters = base.CreateParams;
                parameters.ExStyle |= WS_EX_NOACTIVATE;
                return parameters;
            }
        }

        [STAThread]
        private static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SafeTestWindow());
        }
    }
}
