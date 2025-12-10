using System;
using System.Drawing;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
using System.Xml;

namespace TocViewer
{
    static class Program
    {
[STAThread]
static void Main(string[] args)
{
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);

    string exeDir   = AppDomain.CurrentDomain.BaseDirectory;
    string iniPath  = Path.Combine(exeDir, "tocviewer.ini");
    string ncxPath  = Path.Combine(exeDir, "toc.ncx");

    // Load INI
    var ini = IniReader.Load(iniPath);
    string sumatraPath = ini.ContainsKey("SumatraPath") ? ini["SumatraPath"] : "SumatraPDF.exe";

    // Define bookPath in this scope
    string bookPath = args.Length > 0 ? Path.GetFullPath(args[0]) : "";

    // Validate/extract per your EPUB tool rules
    if (!string.IsNullOrEmpty(bookPath))
    {
        if (!File.Exists(bookPath))
        {
            MessageBox.Show("Book file not found: " + bookPath);
            return;
        }

        // Always extract when there is an argument
        ExtractTocNcx(bookPath, ncxPath);
    }
    else
    {
        // No args: must have an existing local NCX
        if (!File.Exists(ncxPath))
        {
            MessageBox.Show("No TOC available. Drop an EPUB onto the exe to extract a TOC.");
            return;
        }
    }

    // Now bookPath, ncxPath, sumatraPath, args are all in scope
    Application.Run(new TocForm(sumatraPath, bookPath, ncxPath, args));
}


static void ExtractTocNcx(string bookPath, string targetNcx)
{
    var proc = new System.Diagnostics.Process
    {
        StartInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "tar",
            Arguments = "-xOf \"" + bookPath + "\" OEBPS/toc.ncx",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            CreateNoWindow = true,
            WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
        }
    };

    proc.Start();
    using (var fs = new FileStream(targetNcx, FileMode.Create, FileAccess.Write))
    {
        proc.StandardOutput.BaseStream.CopyTo(fs);
    }
    proc.WaitForExit();
}
}
    // Simple INI reader
    public static class IniReader
    {
        public static Dictionary<string,string> Load(string path)
        {
            var dict = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
            if (!File.Exists(path)) return dict;

            foreach (var line in File.ReadAllLines(path))
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                if (line.TrimStart().StartsWith("#")) continue;

                int idx = line.IndexOf('=');
                if (idx > 0)
                {
                    string key = line.Substring(0, idx).Trim();
                    string val = line.Substring(idx + 1).Trim();
                    dict[key] = val;
                }
            }
            return dict;
        }
    }

    // TOC entry container
    public class TocEntry
    {
        public string Label { get; set; }
        public string Href { get; set; }
    public string Id { get; set; }          // navPoint id attribute
    public string PlayOrder { get; set; }   // navPoint playOrder attribute
    }

    public class TocForm : Form
    {
        private TreeView treeView;
        private TextBox searchBox;
        private Label resultsLabel;
        private Button prevButton;
        private Button nextButton;

        private List<TreeNode> searchResults = new List<TreeNode>();
        private int currentIndex = -1;

        private string sumatraPath;
        private string bookPath;
        private string ncxPath;
    private CheckBox lineByLineBox;
    private CheckBox sameLevelBox;

    private bool autoLaunch = false;

        public TocForm(string sumatraPath, string bookPath, string ncxPath, string[] args)
        {
            this.TopMost = true;
            this.sumatraPath = sumatraPath;
            this.bookPath = bookPath;
            this.ncxPath = ncxPath;
this.MinimumSize = new Size(430, 400); // or whatever width/height you need
            Text = "TOC Viewer";
            Width = 430; Height = 800;

            treeView = new TreeView { Dock = DockStyle.Fill, Font = new Font("Segoe UI", 10F, FontStyle.Regular), DrawMode = TreeViewDrawMode.OwnerDrawText };
            treeView.DrawNode += TreeView_DrawNode;
            treeView.NodeMouseDoubleClick += TreeView_NodeMouseDoubleClick;
treeView.HideSelection = false;
treeView.KeyDown += treeView_KeyDown;


//2nd row defines
            prevButton = new Button { Text = "▲\nPrevious", Height = 40, Width = 60, TextAlign = ContentAlignment.MiddleCenter };
            prevButton.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
            prevButton.Click += (s, e) => PrevMatch();

            nextButton = new Button { Text = "Next\n▼", Height = 40, Width = 60, TextAlign = ContentAlignment.MiddleCenter };
nextButton.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
            nextButton.Click += (s, e) => NextMatch();

lineByLineBox = new CheckBox { Text = "Line \nby line", AutoSize = true, Checked = true };
lineByLineBox.Font = new Font("Segoe UI", 10F, FontStyle.Regular);
lineByLineBox.CheckedChanged += (s, e) =>
{
    if (lineByLineBox.Checked) sameLevelBox.Checked = false;
};

sameLevelBox  = new CheckBox { Text = "Same\nLevel", AutoSize = true };
sameLevelBox.Font = new Font("Segoe UI", 10F, FontStyle.Regular);
sameLevelBox.CheckedChanged += (s, e) =>
{
    if (sameLevelBox.Checked) lineByLineBox.Checked = false;
};

CheckBox largeTextBox = new CheckBox { Text = "Larger\n Text", AutoSize = true };
largeTextBox.Font = new Font("Segoe UI", 10F, FontStyle.Regular);
largeTextBox.CheckedChanged += (s, e) =>
{
    if (largeTextBox.Checked)
        treeView.Font = new Font("Segoe UI", 12F, FontStyle.Regular); // larger
    else
        treeView.Font = new Font("Segoe UI", 10F, FontStyle.Regular);  // set a default
};

Button exportButton = new Button { Text = "Export\nAs CSV", Height = 40, Width = 60, TextAlign = ContentAlignment.MiddleCenter };
exportButton.Font = new Font("Segoe UI", 9F, FontStyle.Regular);
exportButton.Click += (s, e) =>
{
    string csvPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "toc.csv");
    ExportTocToCsv(csvPath);
};


// First row panel: Find / Search / Results / AutoGoTo
var searchPanel = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 4, AutoSize = true };
searchPanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));    // Find label
searchPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50)); // Search box
searchPanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));    // Results label
searchPanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));    // AutoGoTo checkbox

Label findLabel = new Label { Text = "Find", AutoSize = true, TextAlign = ContentAlignment.MiddleLeft, Dock = DockStyle.Fill };
findLabel.Font = new Font("Segoe UI", 10F, FontStyle.Regular);

searchBox = new TextBox { Dock = DockStyle.Fill, Margin = new Padding(0, 12, 0, 0) };
searchBox.KeyDown += (s, e) => { if (e.KeyCode == Keys.Enter) SearchTree(searchBox.Text); };
searchBox.Font = new Font("Segoe UI", 10F, FontStyle.Regular);

resultsLabel = new Label { Text = "Found 0\nmatches", AutoSize = true, Margin = new Padding(0, 6, 0, 0), TextAlign = ContentAlignment.MiddleLeft };
resultsLabel.Font = new Font("Segoe UI", 10F, FontStyle.Regular);

CheckBox autoLaunchBox = new CheckBox { Text = "Auto\nGoTo", AutoSize = true };
autoLaunchBox.CheckedChanged += (s, e) => autoLaunch = autoLaunchBox.Checked;
autoLaunchBox.Font = new Font("Segoe UI", 10F, FontStyle.Regular);

searchPanel.Controls.Add(findLabel, 0, 0);
searchPanel.Controls.Add(searchBox, 1, 0);
searchPanel.Controls.Add(resultsLabel, 2, 0);
searchPanel.Controls.Add(autoLaunchBox, 3, 0);

// Second row panel: Prev / Next / LineByLine / SameLevel / Export
var controlPanel = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 6, AutoSize = true };
for (int i = 0; i < 6; i++) controlPanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

controlPanel.Controls.Add(prevButton, 0, 0);
controlPanel.Controls.Add(nextButton, 1, 0);
controlPanel.Controls.Add(lineByLineBox, 2, 0);
controlPanel.Controls.Add(sameLevelBox, 3, 0);
controlPanel.Controls.Add(largeTextBox, 4, 0);
controlPanel.Controls.Add(exportButton, 5, 0);


// Add panels and treeView to form
Controls.Add(treeView);
Controls.Add(controlPanel);
Controls.Add(searchPanel);
ContextMenuStrip cms = new ContextMenuStrip();
cms.Items.Add("Copy", null, (s, ev) =>
{
    if (treeView.SelectedNode != null)
        // OPTIONAL Clipboard.SetText(treeView.SelectedNode.FullPath);
        Clipboard.SetText(treeView.SelectedNode.Text);
});
treeView.ContextMenuStrip = cms;

            LoadToc(ncxPath);

            // Optional startup search
            foreach (string arg in args)
            {
                if (arg.StartsWith("-s="))
                {
                    string phrase = arg.Substring(3).Trim('"');
                    searchBox.Text = phrase;
                    SearchTree(phrase);
                }
            }
        }

        private void LoadToc(string path)
        {
            if (!File.Exists(path)) return;

            XmlDocument doc = new XmlDocument();
            doc.Load(path);

            XmlNamespaceManager nsmgr = new XmlNamespaceManager(doc.NameTable);
            nsmgr.AddNamespace("ncx", "http://www.daisy.org/z3986/2005/ncx/");

            XmlNodeList navPoints = doc.SelectNodes("//ncx:navMap/ncx:navPoint", nsmgr);
            treeView.Nodes.Clear();

            foreach (XmlNode navPoint in navPoints)
            {
                treeView.Nodes.Add(CreateNode(navPoint, nsmgr));
            }
        }
private void treeView_KeyDown(object sender, KeyEventArgs e)
{
    if (e.Control && e.KeyCode == Keys.C)
    {
        if (treeView.SelectedNode != null)
        {
            Clipboard.SetText(treeView.SelectedNode.Text);
        }
    }
}
        private TreeNode CreateNode(XmlNode navPoint, XmlNamespaceManager nsmgr)
        {
            string title = "Untitled";
            XmlNode textNode = navPoint.SelectSingleNode("ncx:navLabel/ncx:text", nsmgr);
            if (textNode != null) title = textNode.InnerText;

            string href = "";
            XmlNode contentNode = navPoint.SelectSingleNode("ncx:content", nsmgr);
            if (contentNode != null && contentNode.Attributes["src"] != null)
                href = contentNode.Attributes["src"].Value;

            TreeNode node = new TreeNode(title);
            node.Tag = new TocEntry { Label = title, Href = href };

            XmlNodeList children = navPoint.SelectNodes("ncx:navPoint", nsmgr);
            foreach (XmlNode child in children)
            {
                node.Nodes.Add(CreateNode(child, nsmgr));
            }

            return node;
        }

private void TreeView_NodeMouseDoubleClick(object sender, TreeNodeMouseClickEventArgs e)
{
    TocEntry entry = e.Node.Tag as TocEntry;
    if (entry != null)
    {
        LaunchViewer(entry.Label);

        // Sync navigation state
        int idx = searchResults.IndexOf(e.Node);
        if (idx >= 0)
        {
            currentIndex = idx;
        }
        else
        {
            // If node isn't part of current searchResults, clear index
            currentIndex = -1;
        }
    }
}

private void TreeView_DrawNode(object sender, DrawTreeNodeEventArgs e)
{
    if (e.Bounds.IsEmpty) return;

    // Always use the base font (no bold)
    Font font = treeView.Font;

    bool selected = (e.State & TreeNodeStates.Selected) != 0;
    //bool isSearchHit = searchResults.Contains(e.Node); // we now need to clear colours for when find is empty
    // Only treat node as a search hit if search text is non-empty and thus ALL NODES active
    bool isSearchHit = !string.IsNullOrWhiteSpace(searchBox.Text) && searchResults.Contains(e.Node);

    Color back = selected ? SystemColors.Highlight :
                 isSearchHit ? Color.Yellow :
                 treeView.BackColor;

    Color fore = selected ? SystemColors.HighlightText :
                 isSearchHit ? Color.DarkRed :
                 treeView.ForeColor;

    using (var b = new SolidBrush(back))
        e.Graphics.FillRectangle(b, e.Bounds);

    TextRenderer.DrawText(
        e.Graphics,
        e.Node.Text,
        font,
        e.Bounds,
        fore,
        TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis
    );
}

        private void SearchTree(string query)
        {
            searchResults.Clear();
            currentIndex = -1;
            if (string.IsNullOrEmpty(query)) return;

            foreach (TreeNode node in treeView.Nodes)
                FindMatches(node, query);

            resultsLabel.Text = "Found " + searchResults.Count + "\n matches";

            if (searchResults.Count > 0)
            {
                currentIndex = 0;
                SelectMatch();
            }
            else
            {
                MessageBox.Show("No matches found.");
            }

            treeView.Invalidate();
        }

        private void FindMatches(TreeNode node, string query)
        {
            if (node.Text.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0)
                searchResults.Add(node);

            foreach (TreeNode child in node.Nodes)
                FindMatches(child, query);
        }

private void SelectMatch()
{
    if (currentIndex >= 0 && currentIndex < searchResults.Count)
    {
        treeView.SelectedNode = searchResults[currentIndex];
        treeView.SelectedNode.EnsureVisible();
        treeView.Focus();              // <-- ensure TreeView has focus
        treeView.Invalidate();         // force redraw
        if (autoLaunch)
        {
            TocEntry entry = treeView.SelectedNode.Tag as TocEntry;
            if (entry != null)
            {
                LaunchViewer(entry.Label);
            }
        }
    }
}

private List<TreeNode> allNodes = new List<TreeNode>();

private void BuildAllNodes()
{
    allNodes.Clear();
    foreach (TreeNode root in treeView.Nodes)
        AddAllNodes(root, allNodes);
}

// Overload 1 that fills searchResults directly
private void AddAllNodes(TreeNode node)
{
    searchResults.Add(node);
    foreach (TreeNode child in node.Nodes)
        AddAllNodes(child);
}

// Overload 2 that fills an arbitrary list
private void AddAllNodes(TreeNode node, List<TreeNode> list)
{
    list.Add(node);
    foreach (TreeNode child in node.Nodes)
        AddAllNodes(child, list);
}

private void NextMatch()
{
    if (searchResults.Count == 0)
    {
        foreach (TreeNode node in treeView.Nodes)
            AddAllNodes(node);
        currentIndex = 0;
    }

    // Case 1: invalid index, resolve nearest and stop
    if (currentIndex < 0 || currentIndex >= searchResults.Count)
    {
        var node = treeView.SelectedNode;
        if (node != null)
        {
            int selPos = allNodes.IndexOf(node);
            if (selPos >= 0)
            {
                for (int i = selPos + 1; i < allNodes.Count; i++)
                {
                    if (searchResults.Contains(allNodes[i]) &&
                        (!sameLevelBox.Checked || allNodes[i].Level == node.Level))
                    {
                        currentIndex = searchResults.IndexOf(allNodes[i]);
                        SelectMatch();
                        return;
                    }
                }
            }
        }
        // fallback: go to first match
        currentIndex = 0;
        SelectMatch();
        return;
    }

    // Case 2: valid index, advance normally
    int start = currentIndex;
    int currentLevel = searchResults[currentIndex].Level;

    do
    {
        currentIndex = (currentIndex + 1) % searchResults.Count;

        if (!sameLevelBox.Checked || searchResults[currentIndex].Level == currentLevel)
            break;

    } while (currentIndex != start);

    SelectMatch();
}

private void PrevMatch()
{
    if (searchResults.Count == 0)
    {
        foreach (TreeNode node in treeView.Nodes)
            AddAllNodes(node);
        currentIndex = 0;
    }

    // Case 1: invalid index, resolve nearest preceding highlight and stop
    if (currentIndex < 0 || currentIndex >= searchResults.Count)
    {
        var node = treeView.SelectedNode;
        if (node != null)
        {
            int selPos = allNodes.IndexOf(node);
            if (selPos >= 0)
            {
                // look backward in allNodes until you hit a highlight
                for (int i = selPos - 1; i >= 0; i--)
                {
                    if (searchResults.Contains(allNodes[i]) &&
                        (!sameLevelBox.Checked || allNodes[i].Level == node.Level))
                    {
                        currentIndex = searchResults.IndexOf(allNodes[i]);
                        SelectMatch();
                        return;
                    }
                }
            }
        }
        // fallback: go to last match
        currentIndex = searchResults.Count - 1;
        SelectMatch();
        return;
    }

    // Case 2: valid index, step backwards normally
    int start = currentIndex;
    int currentLevel = searchResults[currentIndex].Level;

    do
    {
        currentIndex = (currentIndex - 1 + searchResults.Count) % searchResults.Count;

        if (!sameLevelBox.Checked || searchResults[currentIndex].Level == currentLevel)
            break;

    } while (currentIndex != start);

    SelectMatch();
}


private void LaunchViewer(string dest)
{
    var psi = new ProcessStartInfo
    {
        FileName = sumatraPath,
        Arguments = "\"" + bookPath + "\" -reuse-instance -named-dest \"" + dest + "\"",
        UseShellExecute = false
    };
    Process.Start(psi);
}

private void ExportTocToCsv(string csvPath)
{
    using (var writer = new StreamWriter(csvPath))
    {
        // Write header with all fields
        writer.WriteLine("Order,Level,Id,ParentLine,Label,Href");

        int order = 1;
        foreach (TreeNode node in treeView.Nodes)
        {
            WriteNodeCsv(writer, node, 0, ref order, 0);
        }
    }

    MessageBox.Show("TOC exported to " + csvPath);
}

private void WriteNodeCsv(StreamWriter writer, TreeNode node, int level, ref int order, int parentLine)
{
    var entry = node.Tag as TocEntry;
    if (entry != null)
    {
        string line = string.Format("{0},{1},{2},{3},\"{4}\",\"{5}\"",
            order,
            level,
            entry.Id ?? "",
            parentLine > 0 ? parentLine.ToString() : "",
            entry.Label != null ? entry.Label.Replace("\"", "\"\"") : "",
            entry.Href != null ? entry.Href.Replace("\"", "\"\"") : ""
        );

        writer.WriteLine(line);

        int myLine = order;
        order++;

        foreach (TreeNode child in node.Nodes)
        {
            WriteNodeCsv(writer, child, level + 1, ref order, myLine);
        }
    }
}



}
}