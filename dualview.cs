using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Windows.Forms;

public class DualView : Form
{
    private ToolStrip toolStrip;
    private ToolStripButton printButton, openButton, sidebarButton, noteButton;
    private SplitContainer mainSplit, navSplit, canvasSplit;
    private Panel sidebarPanel;
    private TabControl tabLeft, tabRight;
    private Dictionary<string, Image> iconImages = new Dictionary<string, Image>();
    private int sidebarWidth = 150;
    private bool fileHasOutline = false;

    public DualView()
    {
        this.Text = "Twin Viewer";
        this.Size = new Size(1200, 700);
        this.BackColor = Color.Black;
        this.StartPosition = FormStartPosition.CenterScreen;
        this.AutoScaleMode = AutoScaleMode.None;

        LoadIconsFromZip("icons.zip");

        InitializeSplitContainers();
        InitializeToolStrip();
        InitializeCanvasTabs();

        tabLeft.AllowDrop = true;
        tabRight.AllowDrop = true;

        tabLeft.DragEnter += (s, e) =>
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
                e.Effect = DragDropEffects.Copy;
        };

        tabRight.DragEnter += (s, e) =>
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
                e.Effect = DragDropEffects.Copy;
        };

        tabLeft.DragDrop += (s, e) => HandleNoteDrop(e, tabLeft);
        tabRight.DragDrop += (s, e) => HandleNoteDrop(e, tabRight);

        this.Controls.Add(mainSplit);

        this.Shown += (s, e) =>
        {
            navSplit.SplitterDistance = sidebarWidth;
            navSplit.Panel1Collapsed = true;
            canvasSplit.SplitterDistance = canvasSplit.Width / 2;
            canvasSplit.PerformLayout();
            if (fileHasOutline) ToggleSidebar(true);
        };
    }
    private void HandleNoteDrop(DragEventArgs e, TabControl targetTab)
    {
        string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
        foreach (string file in files)
        {
            if (file.EndsWith(".rtf"))
            {
                try
                {
                    NoteEditor editor = new NoteEditor();
                    editor.SetContent(File.ReadAllText(file));
                    TabPage tab = new TabPage(Path.GetFileName(file));
                    tab.Controls.Add(editor);
                    targetTab.TabPages.Add(tab);
                    targetTab.SelectedTab = tab;
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Failed to load note:\n" + ex.Message);
                }
            }
        }
    }

    private void LoadIconsFromZip(string zipPath)
    {
        if (!File.Exists(zipPath)) return;

        try
        {
            using (ZipArchive archive = ZipFile.OpenRead(zipPath))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    if (entry.FullName.EndsWith(".png"))
                    {
                        using (Stream stream = entry.Open())
                        {
                            iconImages[entry.Name.ToLower()] = Image.FromStream(stream);
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("Failed to load icons: " + ex.Message);
        }
    }

    private void InitializeToolStrip()
    {
        toolStrip = new ToolStrip();
        toolStrip.ImageScalingSize = new Size(31, 40);
        toolStrip.BackColor = Color.Black;
        toolStrip.GripStyle = ToolStripGripStyle.Hidden;
        toolStrip.LayoutStyle = ToolStripLayoutStyle.HorizontalStackWithOverflow;
        toolStrip.ShowItemToolTips = true;

        printButton = new ToolStripButton();
        openButton = new ToolStripButton();
        sidebarButton = new ToolStripButton();
        noteButton = new ToolStripButton();

        SetupButton(printButton, "print", "Print document");
        SetupButton(openButton, "open", "Open file");
        SetupButton(sidebarButton, "sidebar", "Toggle sidebar");
        SetupButton(noteButton, "note", "New note tab");

        sidebarButton.Click += (s, e) => ToggleSidebar();
        noteButton.Click += (s, e) => AddNoteTab();

        toolStrip.Items.Add(sidebarButton);
        toolStrip.Items.Add(new ToolStripSeparator() { Margin = new Padding(5, 0, 5, 0) });
        toolStrip.Items.Add(openButton);
        toolStrip.Items.Add(printButton);
        toolStrip.Items.Add(new ToolStripSeparator() { Margin = new Padding(5, 0, 5, 0) });
        toolStrip.Items.Add(noteButton);

        mainSplit.Panel1.Controls.Add(toolStrip);
    }

    private void InitializeSplitContainers()
    {
        mainSplit = new SplitContainer();
        mainSplit.Dock = DockStyle.Fill;
        mainSplit.Orientation = Orientation.Horizontal;
        mainSplit.FixedPanel = FixedPanel.Panel1;
        mainSplit.IsSplitterFixed = true;
        mainSplit.SplitterDistance = 40;

        navSplit = new SplitContainer();
        navSplit.Dock = DockStyle.Fill;
        navSplit.Orientation = Orientation.Vertical;
        navSplit.SplitterDistance = sidebarWidth;

        sidebarPanel = new Panel();
        sidebarPanel.Dock = DockStyle.Fill;
        sidebarPanel.BackColor = Color.DimGray;
        sidebarPanel.BorderStyle = BorderStyle.FixedSingle;

        canvasSplit = new SplitContainer();
        canvasSplit.Dock = DockStyle.Fill;
        canvasSplit.Orientation = Orientation.Vertical;

        navSplit.Panel1.Controls.Add(sidebarPanel);
        navSplit.Panel2.Controls.Add(canvasSplit);
        mainSplit.Panel2.Controls.Add(navSplit);
    }

    private void InitializeCanvasTabs()
    {
        tabLeft = new TabControl();
        tabLeft.Dock = DockStyle.Fill;
        tabLeft.Font = new Font("Segoe UI", 9);
        tabLeft.Appearance = TabAppearance.Normal;

        tabRight = new TabControl();
        tabRight.Dock = DockStyle.Fill;
        tabRight.Font = new Font("Segoe UI", 9);
        tabRight.Appearance = TabAppearance.Normal;

        canvasSplit.Panel1.Controls.Add(tabLeft);
        canvasSplit.Panel2.Controls.Add(tabRight);

        AddSampleTab(tabLeft, "Left Document 1");
        AddSampleTab(tabRight, "Right Document 1");
        //AddNoteTab(); // Add default note tab
        AddNoteTab(loadReadme: true); // Load help tab on launch

    }

    private void AddSampleTab(TabControl tabControl, string title)
    {
        TabPage tab = new TabPage(title);
        tab.BackColor = Color.White;
        tab.Controls.Add(new Label
        {
            Text = "PDF Viewer Canvas",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter
        });
        tabControl.TabPages.Add(tab);
    }

    private void AddNoteTab(bool loadReadme = false)
    {
        TabPage noteTab = new TabPage("Notes");
        NoteEditor editor = new NoteEditor();
        if (loadReadme && File.Exists("readme.rtf"))
        {
            try { editor.SetContent(File.ReadAllText("readme.rtf")); }
            catch { /* fallback silently */ }
        }
        noteTab.Controls.Add(editor);
        tabRight.TabPages.Add(noteTab);
        tabRight.SelectedTab = noteTab;
    }


    private void SetupButton(ToolStripButton button, string baseName, string tooltip)
    {
        button.Tag = baseName;
        button.ToolTipText = tooltip;
        button.AutoSize = false;
        button.Size = new Size(36, 40);
        button.Margin = new Padding(0);
        button.BackColor = Color.Transparent;
        button.DisplayStyle = ToolStripItemDisplayStyle.Image;
        button.Image = GetImage(baseName + ".png");

        button.MouseHover += (s, e) => button.Image = GetImage(baseName + "_over.png") ?? button.Image;
        button.MouseLeave += (s, e) => button.Image = GetImage(baseName + ".png") ?? button.Image;
        button.MouseDown  += (s, e) => button.Image = GetImage(baseName + "_press.png") ?? button.Image;
        button.MouseUp    += (s, e) => button.Image = GetImage(baseName + "_over.png") ?? button.Image;
    }

    private Image GetImage(string name)
    {
        name = name.ToLower();
        return iconImages.ContainsKey(name) ? iconImages[name] : null;
    }

    private void ToggleSidebar(bool forceOpen = false)
    {
        if (forceOpen || navSplit.Panel1Collapsed)
        {
            navSplit.Panel1Collapsed = false;
            navSplit.SplitterDistance = sidebarWidth;
        }
        else
        {
            sidebarWidth = navSplit.SplitterDistance;
            navSplit.Panel1Collapsed = true;
        }
    }

    [STAThread]
    public static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new DualView());
    }
}

