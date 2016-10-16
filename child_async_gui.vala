using GLib;
using Gtk;
using Gdk;
using Posix;
using Pango;

/*
 * valac --pkg posix --pkg gtk+-2.0 -o spawnasyncwithpipestest4 spawnasyncwithpipestest4.vala
 */

namespace SpawnAsyncWithPipesTest4
{
  class MainWindow : Gtk.Window
  {
    Gtk.AccelGroup accelgroup;
    Gtk.ImageMenuItem item_quit;
    Gtk.Menu menu_file;
    Gtk.MenuItem item_file;
    Gtk.MenuBar menubar;
    Gtk.Entry entry;
    Gtk.Button button;
    Gtk.TextView textview;
    Gtk.TextBuffer textbuf;
    Gtk.ScrolledWindow sw;
    Gtk.HBox hbox;
    Gtk.VBox vbox;
    GLib.Pid child_pid;
    int child_stdin;
    int child_stdout;
    int child_stderr;
    uint id_childwatch;
    uint id_stdoutwatch;
    uint id_stderrwatch;
    uint id_hupwatch;
    GLib.IOChannel ioch_stdout;
    GLib.IOChannel ioch_stderr;
    public MainWindow ()
    {
      /* ショートカットキー(アクセラレータ) */
      this.accelgroup = new Gtk.AccelGroup ();
      this.add_accel_group (this.accelgroup);
      /* メニュー項目 */
      this.item_quit = new Gtk.ImageMenuItem.from_stock (Gtk.STOCK_QUIT, accelgroup);
      this.menu_file = new Gtk.Menu ();
      this.menu_file.add (item_quit);
      this.item_file = new Gtk.MenuItem.with_mnemonic ("_File");
      this.item_file.set_submenu (menu_file);
      this.menubar = new Gtk.MenuBar ();
      this.menubar.append (item_file);
      /* 出力のテキストビューの下に1行テキスト入力欄と停止ボタンを横に並べる */
      this.entry = new Gtk.Entry ();
      this.button = new Gtk.Button.from_stock (Gtk.STOCK_STOP);
      this.button.sensitive = false;  // 最初は無効
      this.hbox = new Gtk.HBox (false, 0);
      this.hbox.pack_start (this.entry, true, true, 0);
      this.hbox.pack_start (this.button, false, false, 0);
      this.textview = new Gtk.TextView ();
      this.textbuf = this.textview.buffer;
      this.textview.editable = false;  // 編集不可
      this.textview.modify_font (Pango.FontDescription.from_string ("Monospace, Normal 10"));
      /* レイアウトなど */
      this.sw = new Gtk.ScrolledWindow (null, null);
      this.sw.add (this.textview);
      this.sw.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
      this.vbox = new Gtk.VBox (false, 0);
      this.vbox.pack_start (this.menubar, false, false, 0);
      this.vbox.pack_start (this.sw, true, true, 0);
      this.vbox.pack_start (this.hbox, false, false, 0);
      this.add (this.vbox);
      this.set_size_request (600, 360);
      /* テキスト入力欄をフォーカス */
      this.entry.grab_focus ();
      /* シグナル */
      this.entry.activate += this.on_entry_activated;
      this.button.clicked += (source) =>
      {
        Posix.kill ((Posix.pid_t) this.child_pid, Posix.SIGTERM);
        source.sensitive = false;
      };
      this.item_quit.activate += Gtk.main_quit;
      this.destroy += Gtk.main_quit;
    }
    void close_child (GLib.Pid pid, int status)
    {
      GLib.debug ("close_child()");
      Gtk.TextIter iter;
      string statusmsg;
      GLib.Process.close_pid (pid);
      GLib.Source.remove (this.id_childwatch);
      statusmsg = "child exited, raw status: %d".printf (status);
      if (GLib.Process.if_exited (status))
        statusmsg += " exit status: %d\n".printf (GLib.Process.exit_status (status));
      this.textbuf.get_end_iter (out iter);
      this.textbuf.place_cursor (iter);
      this.textbuf.insert_at_cursor (statusmsg, -1);
      this.textview.scroll_to_mark (this.textbuf.get_insert (), 0, false, 0, 0);
      this.button.sensitive = false;
    }
    bool display_output (GLib.IOChannel source, GLib.IOCondition condition)
    {
      string line;
      size_t length, terminator_pos;
      Gtk.TextIter iter;
      GLib.IOStatus iostatus;
      for (;;)
      {
        try
        {
          GLib.debug ("before read_line()");
          /* FIXME:一部コマンドではここで固まる(仕様?) */
          iostatus = source.read_line (out line, out length, out terminator_pos);
          GLib.debug ("after read_line()");
        }
        catch (GLib.IOChannelError e)
        {
          break;
        }
        catch (GLib.ConvertError e)
        {
          break;
        }
        if (iostatus != GLib.IOStatus.NORMAL)
          return false;
        /* FIXME:実際には表示の更新はすぐには行われない */
        this.textbuf.get_end_iter (out iter);
        this.textbuf.place_cursor (iter);
        this.textbuf.insert_at_cursor (line, -1);
        this.textview.scroll_to_mark (this.textbuf.get_insert (), 0, false, 0, 0);
        /* FIXME:Gtk.main_iteration()では表示は更新されない */
        /*
        for (;;)
        {
          bool pending = Gdk.events_pending ();
          if (pending == false)  // falseが返る?
          {
            GLib.debug ("no pending events");
            break;
          }
          print ("Gtk.main_iteration()\n");
          Gtk.main_iteration ();
        }
        */
      }
      return true;
    }
    void on_entry_activated (Gtk.Entry source)
    {
      string[] argv;
      /* テキスト入力欄から文字列を取り出す */
      string cmdline = source.text;
      source.text = "";  // クリア
      try
      {
        /* コマンド行文字列をリストの形式に変換 */
        GLib.Shell.parse_argv (cmdline, out argv);
      }
      catch (GLib.ShellError e)
      {
        GLib.warning ("Cannot parse command line: %s\n(%s)", cmdline, e.message);
        return;
      }
      GLib.debug ("cmdline: %s", cmdline);
      try
      {
        if (GLib.Process.spawn_async_with_pipes (null,
                                                 argv,
                                                 null,
                                                 GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                                                 null,
                                                 out this.child_pid,
                                                 out this.child_stdin,
                                                 out this.child_stdout,
                                                 out this.child_stderr))
        {
          string encoding;
          this.button.sensitive = true;
//          this.id_childwatch = GLib.ChildWatch.add (child_pid, this.close_child);
          this.id_childwatch = GLib.ChildWatch.add_full (GLib.Priority.LOW, child_pid, this.close_child);
          this.ioch_stdout = new GLib.IOChannel.unix_new (this.child_stdout);
          this.ioch_stderr = new GLib.IOChannel.unix_new (this.child_stderr);
          if (GLib.get_charset (out encoding) == false)
          {
            try
            {
              ioch_stdout.set_encoding (encoding);
              ioch_stderr.set_encoding (encoding);
            }
            catch (GLib.IOChannelError e)
            {
              ;
            }
          }
          this.id_stdoutwatch = this.ioch_stdout.add_watch_full (GLib.Priority.LOW, GLib.IOCondition.IN, this.display_output);
          this.id_stderrwatch = this.ioch_stderr.add_watch_full (GLib.Priority.LOW, GLib.IOCondition.IN, this.display_output);
          this.id_hupwatch = this.ioch_stdout.add_watch_full (GLib.Priority.LOW, GLib.IOCondition.HUP, this.cleanup_ioch);
//          this.id_stdoutwatch = this.ioch_stdout.add_watch (GLib.IOCondition.IN, this.display_output);
//          this.id_stderrwatch = this.ioch_stderr.add_watch (GLib.IOCondition.IN, this.display_output);
//          this.id_hupwatch = this.ioch_stdout.add_watch (GLib.IOCondition.HUP, this.cleanup_ioch);
        }
      }
      catch (GLib.SpawnError e)
      {
        Gtk.TextIter iter;
        GLib.warning ("spawn failed: %s", e.message);
        this.textbuf.get_end_iter (out iter);
        this.textbuf.place_cursor (iter);
        this.textbuf.insert_at_cursor ("Failed to execute \"%s\"\n(%s)\n".printf (cmdline, e.message), -1);
        this.textview.scroll_to_mark (this.textbuf.get_insert (), 0, false, 0, 0);
      }
    }
    bool cleanup_ioch (GLib.IOChannel source, GLib.IOCondition condition)
    {
      GLib.debug ("cleanup_ioch()");
      GLib.Source.remove (this.id_stdoutwatch);
      GLib.Source.remove (this.id_stderrwatch);
      GLib.Source.remove (this.id_hupwatch);
      try
      {
        this.ioch_stdout.shutdown (false);
        this.ioch_stderr.shutdown (false);
      }
      catch (GLib.IOChannelError e)
      {
        ;
      }
      return false;
    }
  }
  class MainClass
  {
    public static int main (string[] args)
    {
      Gtk.init (ref args);
      MainWindow win = new MainWindow ();
      win.show_all ();
      Gtk.main ();
      return 0;
    }
  }
}
