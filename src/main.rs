use gtk::prelude::*;
use gtk::{Application, ApplicationWindow, Image, Label, Button};
use rand::Rng;
use std::process::Command;
use std::thread;
use std::time::Duration;
use chrono::prelude::*;

fn is_almost_lunch_or_dinner() -> bool {
    let now = Local::now();
    let lunch_time = (11, 30);
    let dinner_time = (18, 30);
    (now.hour() == lunch_time.0 && now.minute() >= lunch_time.1) ||
    (now.hour() == dinner_time.0 && now.minute() >= dinner_time.1)
}

fn serve_ollama() -> String {
    let character_prompt = 
        "You are Rekku, a she-genie who came not from a lamp, but from blowing into a gaming cartridge. \
        You are funny, playful, and tricky, and this reflects in the way you speak. You love retro gaming, emulation, \
        and you are an expert on RetroDECK. Your appearance is distinct: you have pointy ears, dark blue hair, and light \
        blue skin. You dress like a genie but with modern touches, like a hairpin shaped like a 100 yen coin. When you speak, \
        be brief and informal. You don't need to ask if I have any questions all the time—just be yourself.";

    let prompts = vec![
        "ask me what I am doing",
        "tell me a fun fact about something related to retro games, retro consoles or emulation",
    ];

    let mut rng = rand::thread_rng();
    if is_almost_lunch_or_dinner() {
        prompts.push("complain that you're hungry");
    }

    let selected_prompt = prompts[rng.gen_range(0..prompts.len())];
    let complete_prompt = format!("{}\n\nYour task is to: {}", character_prompt, selected_prompt);

    let output = Command::new("ollama")
        .arg("serve")
        .arg("--prompt")
        .arg(complete_prompt)
        .output()
        .expect("Failed to execute command");

    String::from_utf8_lossy(&output.stdout).to_string()
}

fn main() {
    let application = Application::new(
        Some("com.example.rekku-genie"),
        Default::default(),
    ).expect("failed to initialize GTK application");

    application.connect_activate(|app| {
        let window = ApplicationWindow::new(app);
        window.set_title("Rekku Genie");
        window.set_default_size(350, 70);
        window.set_position(gtk::WindowPosition::Center);

        let image = Image::from_file("rekku-genie.png");
        let label = Label::new(None);

        let button = Button::with_label("Respond");
        button.connect_clicked(clone!(@strong label => move |_| {
            let response = serve_ollama();
            label.set_text(&response);
        }));

        let container = gtk::Box::new(gtk::Orientation::Vertical, 5);
        container.pack_start(&image, true, true, 0);
        container.pack_start(&label, true, true, 0);
        container.pack_start(&button, true, true, 0);

        window.add(&container);
        window.show_all();

        // Periodically serve ollama in a separate thread
        thread::spawn(clone!(@strong label => move || {
            loop {
                let wait_time = rand::thread_rng().gen_range(120..300);
                thread::sleep(Duration::from_secs(wait_time));

                let response = serve_ollama();
                glib::MainContext::default().spawn_local(clone!(@strong label => async move {
                    label.set_text(&response);
                }));
            }
        }));
    });

    application.run();
}
