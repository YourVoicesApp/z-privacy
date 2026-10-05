//! The Model Gateway: one door between a workspace and a model.
//!
//! The owner's words for this phase: «this is not a stage where two models are
//! added to Z; this is the first time we are building a piece of GAZA itself».
//! So the shape is **Workspace ↓ Gateway ↓ Provider/Model**, and not «Z Chat ↓
//! GPT». A coding workspace, a document task, a school's workspace — each is
//! another caller of this module, and none of them is allowed to need a change
//! inside a provider.
//!
//! Four things are kept apart on purpose, because each one changes for its own
//! reasons:
//!
//! * a **provider** is where a request goes, and how it is spoken to;
//! * a **model** is what answers, with what it can do;
//! * a **credential** is what opens the door, and belongs to one provider;
//! * a **request** is what is being asked, which is not a chat message.
//!
//! # The two bodies, and why they are two types
//!
//! [`Body::Protected`] carries a [`PayloadHandle`] — a handle, never text. The
//! only reader of a payload's outgoing text is `providers::ask`, and gate G16
//! fails the build if the name appears anywhere else. So the protected path
//! **cannot** be handed raw text: there is no argument for it.
//!
//! [`Body::Direct`] carries text, because that is what Direct Mode is: the
//! person chose to send a document as it stands. It is a different type, taken
//! by a different function, and nothing anywhere turns one into the other. In
//! particular there is **no fallback**: a protected send that fails is a
//! protected send that failed, and it is reported.

use zeroize::Zeroizing;

use crate::api::{ApiResult, ModelUsage, PayloadHandle};

/// Where a request is going: a provider, and a model of that provider.
///
/// The model is optional because a provider's configured model is the answer
/// when a caller has no opinion — a model on this machine is whatever the
/// person called it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Target {
    pub provider_id: String,
    pub model_id: Option<String>,
}

/// What is being asked. V1 carries text, and the shape does not close the door.
///
/// Deliberately not named for a chat: the next callers are a document task and
/// a coding task, and a type called `ChatRequest` would have had to be replaced
/// rather than extended.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum Task {
    /// One question, answered once. The only task V1 implements.
    Answer,
}

/// What the model is told about the work, as against what was said in it.
///
/// Two lists, because they have different lifetimes and different owners. A
/// workspace's instructions belong to the workspace and outlive any
/// conversation; a conversation's turns belong to the conversation. A coding
/// workspace will put a repository's rules in the first and nothing in it will
/// have to move.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct Context {
    pub workspace: Vec<String>,
    pub history: Vec<String>,
}

/// The body of a request, and the whole of the difference between the modes.
pub(crate) enum Body {
    /// A handle to a payload the core built and audited. No text.
    Protected(PayloadHandle),
    /// Text the person chose to send as it stands.
    Direct(Zeroizing<String>),
}

/// One request to one model.
pub(crate) struct Request {
    pub target: Target,
    pub task: Task,
    pub context: Context,
    pub body: Body,
}

/// What came back, and what it cost.
pub(crate) struct Answer {
    pub text: String,
    pub usage: ModelUsage,
}

/// Send a request. The one door.
///
/// Both modes come through here, and the body decides which path is taken —
/// which is why the body is a type and not a flag. Nothing in this function
/// reads a language, a document or a session: the gateway knows a provider, a
/// model, a credential and some text, and a German letter and a Swedish one
/// reach it as the same three things.
pub(crate) fn send(request: Request) -> ApiResult<Answer> {
    let Request {
        target,
        task: Task::Answer,
        context,
        body,
    } = request;
    let login = crate::ops::login_for(&target.provider_id)?;
    let model = target
        .model_id
        .filter(|m| !m.trim().is_empty())
        .unwrap_or_else(|| login.model.clone());
    let started = std::time::Instant::now();

    let outcome = match body {
        // The protected path hands the provider a handle's text and never
        // sees it here: `providers::ask` is the only reader there is.
        Body::Protected(handle) => crate::providers::ask(
            handle,
            &target.provider_id,
            login.credential.expose(),
            &login.base,
            &model,
            &instructions(&context),
        ),
        // The direct path is the person's choice, and it is a different
        // function with a different argument. There is no way to arrive here
        // from a failed protected send.
        Body::Direct(text) => crate::providers::ask_direct(
            &target.provider_id,
            login.credential.expose(),
            &login.base,
            &model,
            &text,
            &instructions(&context),
        ),
    };

    let millis = started.elapsed().as_millis().min(u128::from(u32::MAX)) as u32;
    let said = outcome?;
    Ok(Answer {
        usage: ModelUsage {
            provider_id: target.provider_id,
            model_id: model,
            // As the provider reported them. Nothing is estimated: a number we
            // were not given is 0, and 0 means «not stated».
            input_units: said.input_units,
            output_units: said.output_units,
            millis,
            ok: true,
        },
        text: said.text,
    })
}

/// The instructions a request carries, flattened for a provider that takes one
/// system message.
///
/// The workspace's lines first, then the conversation's: the workspace is the
/// standing truth and the conversation is what happened. A provider that can
/// take them apart will be given them apart; this is V1's flattening and it
/// lives here rather than in a provider, so no provider learns what a workspace
/// is.
fn instructions(context: &Context) -> String {
    let mut out = String::new();
    for line in context.workspace.iter().chain(context.history.iter()) {
        if line.trim().is_empty() {
            continue;
        }
        if !out.is_empty() {
            out.push_str("\n\n");
        }
        out.push_str(line);
    }
    out
}
