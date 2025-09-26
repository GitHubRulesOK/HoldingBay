using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;
using Microsoft.VisualBasic;

public class NoteEditor : UserControl
{
  private RichTextBox editor;
  private ToolStrip toolStripTop; private ToolStrip toolStripBottom;
  private ToolStripButton openButton, saveButton, exportHtmlButton, exportMdButton, imageButton;
  private ToolStripButton fontButton, colorButton, boldButton, italicButton, underlineButton, highlightMarkButton;
  private ToolStripButton undoButton, redoButton, findButton, findNextButton, replaceButton, replaceAllButton, highlightFindButton;
  private ToolStripTextBox findBox;
  private ToolStripLabel matchCountLabel;
  private int lastSearchIndex = 0;
  private List<HighlightRange> permanentHighlights = new List<HighlightRange>();

  public NoteEditor() // Constructor
  {
    this.Dock = DockStyle.Fill;
    this.BackColor = Color.White;

    // Define editor UX
    editor = new RichTextBox();
    editor.Dock = DockStyle.Fill;
    float baseSize = this.DeviceDpi > 96 ? 12f : 10f;
    editor.Font = new Font("Segoe UI", baseSize);
    editor.AllowDrop = true;
    int start = editor.SelectionStart;
    int length = editor.SelectionLength;
    Color chosenColor = Color.LightGreen; // or from a ColorDialog

    editor.Select(start, length);
    editor.SelectionBackColor = chosenColor;
    bool overlaps = false;
    foreach (HighlightRange h in permanentHighlights)
    {
      if (start < h.Start + h.Length && h.Start < start + length)
      {
        overlaps = true;
        break;
      }
    }
    if (!overlaps)
    {
      permanentHighlights.Add(new HighlightRange(start, length, chosenColor));
    }

    // Define toolbarS
    toolStripTop = new ToolStrip(); toolStripBottom = new ToolStrip();
    toolStripTop.Dock = DockStyle.Top; toolStripBottom.Dock = DockStyle.Top;
    toolStripTop.RenderMode = ToolStripRenderMode.System;
    toolStripBottom.RenderMode = ToolStripRenderMode.System;

    Font toolbarFont = new Font("Segoe UI", baseSize); // Use a common system font
    try //Debug any font issue
    { toolStripTop.Font = toolbarFont; }
    catch (Exception ex)
    { MessageBox.Show("Font error: " + ex.Message);}
    toolStripBottom.Font = toolbarFont;


    // Manually set height to accommodate larger font
    //toolStripTop.AutoSize = false;
    //toolStripTop.Height = (int)(toolbarFont.Size * 2.2f);
    //toolStripBottom.AutoSize = false;
    //toolStripBottom.Height = (int)(toolbarFont.Size * 2.2f);

    int itemHeight = toolStripTop.Height - 0; // Slight padding

    foreach (ToolStripItem item in toolStripTop.Items)
    {
        item.Font = toolbarFont;
        item.AutoSize = false;
        item.Height = itemHeight;
        item.Margin = new Padding(2); // Optional: add spacing
    }

foreach (ToolStripItem item in toolStripBottom.Items)
{
    item.Font = toolbarFont;
    item.AutoSize = false;
    item.Height = itemHeight;
    item.Margin = new Padding(2);
}
    // Add editor 1st fill space
    this.Controls.Add(editor);
    // Add toolbars 2nd
    this.Controls.Add(toolStripBottom); // Bottom 2nd so pushes editor down
    this.Controls.Add(toolStripTop); // Top 3rd so pushes both down

    editor.KeyDown += (s, e) =>
    {
        if (e.Control && e.KeyCode == Keys.Z) editor.Undo();
        if (e.Control && e.KeyCode == Keys.Y) editor.Redo();
    };

    editor.DragEnter += (s, e) =>
    {
      if (e.Data.GetDataPresent(DataFormats.FileDrop))
        e.Effect = DragDropEffects.Copy;
    };

    editor.DragDrop += (s, e) =>
    {
      string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
      foreach (string file in files)
      {
        if (file.EndsWith(".rtf"))
        {
          try
          {
            editor.LoadFile(file, RichTextBoxStreamType.RichText);
            UpdateFontPicker();
          }
          catch (Exception ex)
          {
            MessageBox.Show("Failed to load file:\n" + ex.Message);
          }
        }
      }
    };

    ContextMenuStrip menu = new ContextMenuStrip();
    menu.Items.Add("Cut", null, (s, e) => editor.Cut());
    menu.Items.Add("Copy", null, (s, e) => editor.Copy());
    menu.Items.Add("Paste", null, (s, e) => editor.Paste());
    menu.Items.Add("Select All", null, (s, e) => editor.SelectAll());
    editor.ContextMenuStrip = menu;

    openButton = new ToolStripButton("📂");
    openButton.ToolTipText = "Open note file";
    openButton.Click += (s, e) => OpenNote();

    saveButton = new ToolStripButton("💾");
    saveButton.ToolTipText = "Save note file";
    saveButton.Click += (s, e) => SaveNote();

    fontButton = new ToolStripButton("A");
    fontButton.ToolTipText = "Change Font";
    fontButton.Click += (s, e) =>
    {
        FontDialog fontDialog = new FontDialog();

        // Use current selection font if available
        if (editor.SelectionFont != null)
        {
            fontDialog.Font = editor.SelectionFont;
        }
        else
        {
            fontDialog.Font = editor.Font; // fallback to editor default
        }

        if (fontDialog.ShowDialog() == DialogResult.OK)
        {
            editor.SelectionFont = fontDialog.Font;
            UpdateFontPicker(); // optional: refresh tooltip or picker
        }
    };

    colorButton = new ToolStripButton("🎨");
    colorButton.ToolTipText = "Change Colour";
    colorButton.Click += (s, e) =>
    {
        ColorDialog colorDialog = new ColorDialog();
        if (colorDialog.ShowDialog() == DialogResult.OK)
            editor.SelectionColor = colorDialog.Color;
    };

    boldButton = new ToolStripButton("B");
    boldButton.ToolTipText = "Bold";
    boldButton.Click += (s, e) => ToggleStyle(FontStyle.Bold);

    italicButton = new ToolStripButton("I");
    italicButton.ToolTipText = "Italic";
    italicButton.Click += (s, e) => ToggleStyle(FontStyle.Italic);

    underlineButton = new ToolStripButton("U");
    underlineButton.ToolTipText = "Underline";
    underlineButton.Click += (s, e) => ToggleStyle(FontStyle.Underline);

    highlightMarkButton = new ToolStripButton("🖍");
    highlightMarkButton.ToolTipText = "Highlight Selected Text";
    highlightMarkButton.Click += (s, e) =>
    {
        if (editor.SelectionLength > 0)
        {
            ColorDialog dialog = new ColorDialog();
            if (dialog.ShowDialog() == DialogResult.OK)
            {
                editor.SelectionBackColor = dialog.Color;
            }
        }
        else
        {
            MessageBox.Show("Please select text to highlight.");
        }
    };

    imageButton = new ToolStripButton("📷");
    imageButton.ToolTipText = "Paste image from clipboard";
    imageButton.Click += (s, e) =>
    {
      if (Clipboard.ContainsImage())
        editor.Paste();
      else
        MessageBox.Show("Clipboard does not contain an image.");
    };

    undoButton = new ToolStripButton("↺");
    undoButton.ToolTipText = "Undo";
    undoButton.Click += (s, e) => editor.Undo();

    redoButton = new ToolStripButton("↻");
    redoButton.ToolTipText = "Redo";
    redoButton.Click += (s, e) => editor.Redo();

    exportHtmlButton = new ToolStripButton("🌐");
    exportHtmlButton.ToolTipText = "Export as HTML";
    exportHtmlButton.Click += (s, e) => ExportAsStyledHtml();

    exportMdButton = new ToolStripButton("📝");
    exportMdButton.ToolTipText = "Export as Markdown";
    exportMdButton.Click += (s, e) => ExportAsStyledMarkdown();

    findBox = new ToolStripTextBox();
    findBox.ToolTipText = "Text to find";
    findBox.TextChanged += (s, e) => HighlightAllMatches(findBox.Text);

    findButton = new ToolStripButton("🔍");
    findButton.ToolTipText = "Find";
    findButton.Click += (s, e) =>
    {
        string query = findBox.Text;
        int index = editor.Text.IndexOf(query, StringComparison.OrdinalIgnoreCase);
        if (index >= 0)
        {
            editor.Select(index, query.Length);
            editor.ScrollToCaret();
            editor.Focus();
        }
        else
        {
            MessageBox.Show("Text not found.");
        }
    };

findNextButton = new ToolStripButton("▶");
findNextButton.ToolTipText = "Next";
findNextButton.Click += (s, e) => FindNext();

replaceButton = new ToolStripButton("🔄");
replaceButton.ToolTipText = "Replace";
replaceButton.Click += (s, e) => ReplaceCurrent();

replaceAllButton = new ToolStripButton("🔄All");
replaceAllButton.ToolTipText = "ReplaceAll";
replaceAllButton.Click += (s, e) => ReplaceAll();

highlightFindButton = new ToolStripButton("🖍");
highlightFindButton.ToolTipText = "Highlight all matches";
highlightFindButton.Click += (s, e) => HighlightAllMatches(findBox.Text);

    matchCountLabel = new ToolStripLabel("Matches: 0");

    editor.SelectionChanged += (s, e) => UpdateFontPicker();

    // Add buttons and separators to toolStripTop and toolStripBottom
    // Example:🌞 / 🌜
    // toolStripTop.Items.Add(openButton);
    // toolStripBottom.Items.Add(findBox);
    // toolStripBottom.Items.Add(findButton);

    toolStripTop.Items.Add(openButton);
    toolStripTop.Items.Add(saveButton);
    toolStripTop.Items.Add(new ToolStripSeparator());
    toolStripTop.Items.Add(fontButton);
    toolStripTop.Items.Add(colorButton);
    toolStripTop.Items.Add(boldButton);
    toolStripTop.Items.Add(italicButton);
    toolStripTop.Items.Add(underlineButton);
    toolStripTop.Items.Add(highlightMarkButton);
    toolStripTop.Items.Add(new ToolStripSeparator());
    toolStripTop.Items.Add(imageButton);
    toolStripTop.Items.Add(new ToolStripSeparator());
    toolStripTop.Items.Add(undoButton);
    toolStripTop.Items.Add(redoButton);
    toolStripTop.Items.Add(new ToolStripSeparator());
    toolStripBottom.Items.Add(exportHtmlButton);
    toolStripBottom.Items.Add(exportMdButton);
    toolStripBottom.Items.Add(new ToolStripSeparator());
    toolStripBottom.Items.Add(findBox);
    toolStripBottom.Items.Add(findButton);
    toolStripBottom.Items.Add(findNextButton);
    toolStripBottom.Items.Add(replaceButton);
    toolStripBottom.Items.Add(replaceAllButton);
    toolStripBottom.Items.Add(new ToolStripSeparator());
    toolStripBottom.Items.Add(highlightFindButton);
    toolStripBottom.Items.Add(matchCountLabel);
    ToolStripButton clearHighlightsButton = new ToolStripButton("🧹");
    clearHighlightsButton.ToolTipText = "Clear Find Highlights";
    clearHighlightsButton.Click += (s, e) => ClearFindHighlights();
    toolStripBottom.Items.Add(clearHighlightsButton);
    toolStripBottom.Items.Add(new ToolStripSeparator());

  }

private void ApplyPermanentHighlight()
{
    if (editor.SelectionLength == 0)
    {
        MessageBox.Show("Please select text to mark.");
        return;
    }

    ColorDialog dialog = new ColorDialog();
    if (dialog.ShowDialog() != DialogResult.OK) return;

    int start = editor.SelectionStart;
    int length = editor.SelectionLength;
    Color chosenColor = dialog.Color;

    editor.SelectionBackColor = chosenColor;

    // Avoid duplicate or overlapping highlights
    foreach (HighlightRange h in permanentHighlights)
    {
        if (start < h.Start + h.Length && h.Start < start + length)
            return;
    }

    permanentHighlights.Add(new HighlightRange(start, length, chosenColor));
    editor.SelectionLength = 0;
}

  private void ReapplyPermanentHighlights()
  {
    foreach (HighlightRange range in permanentHighlights)
    {
      editor.Select(range.Start, range.Length);
      editor.SelectionBackColor = range.Color;
    }
    editor.SelectionLength = 0;
  }

  private void ToggleStyle(FontStyle style)
  {
    if (editor.SelectionFont == null) return;
    Font current = editor.SelectionFont;
    FontStyle newStyle = current.Style ^ style;
    editor.SelectionFont = new Font(current, newStyle);
  }

private void UpdateFontPicker()
{
    Font selFont = editor.SelectionFont;

    if (selFont != null)
    {
        fontButton.ToolTipText = string.Format("{0}, {1}pt", selFont.Name, selFont.SizeInPoints);
    }
    else
    {
        fontButton.ToolTipText = "Mixed fonts";
    }
}

  private void OpenNote()
  {
    OpenFileDialog dialog = new OpenFileDialog();
    dialog.Filter = "Rich Text Format (*.rtf)|*.rtf|Text Files (*.txt)|*.txt";
    dialog.Title = "Open Note";

    if (dialog.ShowDialog() == DialogResult.OK)
    {
      try
      {
        if (dialog.FileName.EndsWith(".rtf")) {
          editor.LoadFile(dialog.FileName, RichTextBoxStreamType.RichText);
          UpdateFontPicker();
        }
        else
          editor.LoadFile(dialog.FileName, RichTextBoxStreamType.PlainText);
      }
      catch (Exception ex)
      {
        MessageBox.Show("Failed to open file:\n" + ex.Message);
      }
    }
  }

  private void SaveNote()
  {
    SaveFileDialog dialog = new SaveFileDialog();
    dialog.Filter = "Rich Text Format (*.rtf)|*.rtf|Text Files (*.txt)|*.txt";
    dialog.Title = "Save Note";

    if (dialog.ShowDialog() == DialogResult.OK)
    {
      try
      {
        if (dialog.FileName.EndsWith(".rtf"))
          editor.SaveFile(dialog.FileName, RichTextBoxStreamType.RichText);
        else
          editor.SaveFile(dialog.FileName, RichTextBoxStreamType.PlainText);
      }
      catch (Exception ex)
      {
        MessageBox.Show("Failed to save file:\n" + ex.Message);
      }
    }
  }

private void ExportAsStyledHtml()
{
  SaveFileDialog dialog = new SaveFileDialog();
  dialog.Filter = "HTML File (*.html)|*.html";
  dialog.Title = "Export as HTML";

  if (dialog.ShowDialog() == DialogResult.OK)
  {
    try
    {
      StringBuilder html = new StringBuilder();
      html.Append("<html><body style='font-family:Segoe UI;font-size:14px;'>");

      int i = 0;
      while (i < editor.TextLength)
      {
        editor.Select(i, 1);
        Font baseFont = editor.SelectionFont;
        if (baseFont == null)
        {
          html.Append(System.Net.WebUtility.HtmlEncode(editor.Text[i].ToString()));
          i++;
          continue;
        }

        int runStart = i;
        while (i < editor.TextLength)
        {
          editor.Select(i, 1);
          Font f = editor.SelectionFont;
          if (f == null || f.Bold != baseFont.Bold || f.Italic != baseFont.Italic || f.Underline != baseFont.Underline)
            break;
          i++;
        }

        string segment = editor.Text.Substring(runStart, i - runStart);
        string encoded = System.Net.WebUtility.HtmlEncode(segment);

        if (baseFont.Bold) html.Append("<b>");
        if (baseFont.Italic) html.Append("<i>");
        if (baseFont.Underline) html.Append("<u>");

        html.Append(encoded.Replace("\n", "<br>"));

        if (baseFont.Underline) html.Append("</u>");
        if (baseFont.Italic) html.Append("</i>");
        if (baseFont.Bold) html.Append("</b>");
      }

      html.Append("</body></html>");
      File.WriteAllText(dialog.FileName, html.ToString());
    }
    catch (Exception ex)
    {
      MessageBox.Show("Failed to export HTML:\n" + ex.Message);
    }
  }
}

private void ExportAsStyledMarkdown()
{
    SaveFileDialog dialog = new SaveFileDialog();
    dialog.Filter = "Markdown File (*.md)|*.md";
    dialog.Title = "Export as Markdown";

    if (dialog.ShowDialog() != DialogResult.OK) return;

    try
    {
        StringBuilder md = new StringBuilder();
        string[] lines = editor.Text.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);

        foreach (string line in lines)
        {
            string trimmed = line.Trim();

            if (string.IsNullOrWhiteSpace(trimmed))
            {
                md.AppendLine();
                continue;
            }

            // Header detection
            if (trimmed.StartsWith("#") || trimmed.StartsWith("##"))
            {
                md.AppendLine(trimmed);
                continue;
            }

            // Bullet list detection
            if (trimmed.StartsWith("•") || trimmed.StartsWith("- ") || trimmed.StartsWith("* "))
            {
                md.AppendLine(trimmed);
                continue;
            }

            // Code block detection
            if (trimmed.StartsWith("    ") || trimmed.StartsWith("\t"))
            {
                md.AppendLine("```");
                md.AppendLine(trimmed);
                md.AppendLine("```");
                continue;
            }

            // Escape special characters
            string escaped = trimmed.Replace("*", "\\*").Replace("_", "\\_").Replace("#", "\\#");

            md.AppendLine(escaped);
        }

        File.WriteAllText(dialog.FileName, md.ToString());
    }
    catch (Exception ex)
    {
        MessageBox.Show("Failed to export Markdown:\n" + ex.Message);
    }
}

private void FindText()
{
    string query = findBox.Text;
    lastSearchIndex = editor.Find(query, 0, RichTextBoxFinds.None);
    if (lastSearchIndex >= 0)
    {
        editor.Select(lastSearchIndex, query.Length);
        editor.ScrollToCaret();
        editor.Focus();
        lastSearchIndex += query.Length;
    }
    else
    {
        MessageBox.Show("Text not found.");
        lastSearchIndex = 0;
    }
}

private void FindNext()
{
    string query = findBox.Text;
    int index = editor.Find(query, lastSearchIndex, RichTextBoxFinds.None);
    if (index >= 0)
    {
        editor.Select(index, query.Length);
        editor.ScrollToCaret();
        editor.Focus();
        lastSearchIndex = index + query.Length;
    }
    else
    {
        MessageBox.Show("No more matches.");
        lastSearchIndex = 0;
    }
}

private void ReplaceCurrent()
{
    if (editor.SelectedText == findBox.Text)
        editor.SelectedText = Prompt("Replace with:", editor.SelectedText);
}

private void ReplaceAll()
{
    string query = findBox.Text;
    string replacement = Prompt("Replace all with:", query);
    editor.Text = editor.Text.Replace(query, replacement);
}

private string Prompt(string title, string defaultValue)
{
    return Microsoft.VisualBasic.Interaction.InputBox(title, "Replace", defaultValue);
//string replacement = Interaction.InputBox("Replace with:", "Replace", defaultValue);
}

private void ClearFindHighlights() //place before private void HighlightAllMatches
{
    int startIndex = 0;
    while (startIndex < editor.TextLength)
    {
        editor.Select(startIndex, 1);
        if (editor.SelectionBackColor == Color.LightYellow)
            editor.SelectionBackColor = Color.White;
        startIndex++;
    }
    editor.DeselectAll();
}

private void HighlightAllMatches(string query)
{
    ClearTemporaryHighlights();

    int startIndex = 0;
    int matchCount = 0;

    while (startIndex < editor.TextLength)
    {
        int index = editor.Find(query, startIndex, RichTextBoxFinds.None);
        if (index < 0) break;

        editor.Select(index, query.Length);
        editor.SelectionBackColor = Color.Yellow;
        startIndex = index + query.Length;
        matchCount++;
    }

    editor.DeselectAll();
    matchCountLabel.Text = string.Format("Matches: {0}", matchCount);
}

  private void ClearTemporaryHighlights()
  {
    for (int i = 0; i < editor.TextLength; i++)
    {
        editor.Select(i, 1);
        if (editor.SelectionBackColor == Color.Yellow)
            editor.SelectionBackColor = Color.White;
    }

    // Reapply permanent highlights
    foreach (HighlightRange range in permanentHighlights)
    {
      editor.Select(range.Start, range.Length);
      editor.SelectionBackColor = range.Color;
    }
    editor.DeselectAll();
  }

  public class HighlightRange
  {
      public int Start { get; set; }
      public int Length { get; set; }
      public Color Color { get; set; }
      public HighlightRange(int start, int length, Color color)
      {
        Start = start; Length = length; Color = color;
      }
  }

  public string GetContent()
  {
    return editor.Rtf;
  }

  public void SetContent(string rtf)
  {
    try
    {
        editor.Rtf = rtf;
    }
    catch (Exception ex)
    {
        MessageBox.Show("RTF load failed: " + ex.Message);
        editor.Text = "Failed to load RTF.";
    }
  }

}
