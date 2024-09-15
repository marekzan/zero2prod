use std::net::TcpListener;
use zero2prod::{configuration::get_configuration, startup::run};

#[tokio::main]
async fn main() -> Result<(), std::io::Error> {
    let configuration = get_configuration().expect("Failed to read configuration.");
    let address = format!("localhost:{}", configuration.application_port);
    let listener = TcpListener::bind(address)?;
    run(listener)?.await // This is the same as the commented out code below
                         //
                         // match run() {
                         //     Ok(server) => server.await,
                         //     Err(e) => {
                         //         eprintln!("Application error: {}", e);
                         //         Err(e)
                         //     }
                         // }
}
