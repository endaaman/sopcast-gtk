using Gtk;
using GLib;
/* using Soup; */



class Sopurl : GLib.Object {
  string host;
  string remotePort;
  string localPort;
  public Sopurl(string sopurl) {
  }
}

class Sopcast : GLib.Object {
  uint id_childwatch;

  GLib.Pid pid;
  private bool is_started() {
    return this.pid != 0;
  }

  private void close_child(GLib.Pid pid, int status) {
    print ("child exited, raw status: %d", status);
    if (GLib.Process.if_exited (status)) {
      print (" exit status: %d", GLib.Process.exit_status (status));
    }
    print ("\n");
    GLib.Process.close_pid(pid);
    GLib.Source.remove(this.id_childwatch);

    this.pid = 0;
  }

  public bool start(string sopurl) {
    if (this.is_started()) {
      print ("Process is already started\n");
      return false;
    }
    string[] env = Environ.get();
    try {
      GLib.Process.spawn_async_with_pipes(
        null,
        {"sopcast",},
        env,
        GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
        null,
        out this.pid,
        null,
        null,
        null);
      this.id_childwatch = GLib.ChildWatch.add(this.pid, this.close_child);
    } catch (GLib.SpawnError e) {
      GLib.warning("spawn failed: %s", e.message);
      return false;
    }
    return true;
  }

  public void stop() {
    if (!this.is_started()) {
      print ("Process is not started\n");
      return;
    }
    stdout.printf(@"kill -9 $(this.pid)\n");
    try {
      Process.spawn_command_line_sync(@"kill -9 $(this.pid)", null, null, null);
    } catch (SpawnError e) {
      stdout.printf ("Error: %s\n", e.message);
    }
  }
}


class MainWindow : Gtk.Window {
  Gtk.Entry entry;
  Gtk.Button btnSpawn;
  Gtk.Button btnKill;
  Gtk.Box vbox;

  GLib.Pid child_pid;

  public MainWindow(string sopurl) {
    this.title = "Sopcast Gtk";
    this.border_width = 8;
    this.window_position = WindowPosition.CENTER;
    this.set_default_size (350, 70);

    this.entry = new Gtk.Entry();

    this.btnSpawn = new Button.with_label("spwan");
    this.btnSpawn.clicked += ()=> {
      this.btnSpawn.set_sensitive(false);
    };

    this.btnKill = new Button.with_label("kill");
    this.btnKill.clicked += ()=> {
    };

    this.vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);;
    this.vbox.pack_start(this.entry, false, false, 0);
    this.vbox.pack_start(this.btnSpawn, false, false, 0);
    this.vbox.pack_start(this.btnKill, false, false, 0);
    this.add(this.vbox);

    this.destroy += this.on_destroy;
    this.delete_event += this.on_delete_event;
  }


  public bool on_delete_event () {
    return false;
  }


  public void on_destroy() {
    Gtk.main_quit();
  }
}


class MainClass {
  public static void main (string[] args)
  {
    Gtk.init(ref args);
    string sopurl = "";
    if (args.length > 1) {
      sopurl = args[1];
    }
    MainWindow win = new MainWindow(sopurl);
    win.show_all();
    Gtk.main();
  }
}
