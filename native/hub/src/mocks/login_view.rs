use flatbuffers::FlatBufferBuilder;
use zeroflat_fbs::fbs::zeroflat::{
    ActionUpdateState, ActionUpdateStateArgs,
    Button, ButtonArgs, ButtonVariant,
    Card, CardArgs,
    Header, HeaderArgs,
    Scaffold, ScaffoldArgs,
    StacAction, StacNode, StacRoot, StacRootArgs,
    TextField, TextFieldArgs,
    finish_stac_root_buffer,
};

/// Builds a Login screen FlatBuffer and returns the serialized bytes.
///
/// Tree: StacRoot → Scaffold
///   header  → Header ("Sign in")
///   content → Card ("Welcome back") → TextField (email-field)
///   footer  → Button ("Sign in", primary)
pub fn build() -> Vec<u8> {
    let mut fbb = FlatBufferBuilder::with_capacity(512);

    // ── email TextField ───────────────────────────────────────────────────────
    let tf_id = fbb.create_string("email-field");
    let tf_label = fbb.create_string("Email");
    let tf_hint = fbb.create_string("you@example.com");
    let email_key = fbb.create_string("auth.email");
    let email_on_change = ActionUpdateState::create(&mut fbb, &ActionUpdateStateArgs {
        key: Some(email_key),
        value: None,
    });
    let email_field = TextField::create(&mut fbb, &TextFieldArgs {
        id: Some(tf_id),
        label: Some(tf_label),
        hint: Some(tf_hint),
        on_change_type: StacAction::ActionUpdateState,
        on_change: Some(email_on_change.as_union_value()),
        ..Default::default()
    });

    // ── Card wrapping the email field ─────────────────────────────────────────
    let card_id = fbb.create_string("login-card");
    let card_title = fbb.create_string("Welcome back");
    let login_card = Card::create(&mut fbb, &CardArgs {
        id: Some(card_id),
        title: Some(card_title),
        child_type: StacNode::TextField,
        child: Some(email_field.as_union_value()),
        ..Default::default()
    });

    // ── Sign-in Button (footer) ───────────────────────────────────────────────
    let btn_id = fbb.create_string("signin-btn");
    let btn_label = fbb.create_string("Sign in");
    let submit_key = fbb.create_string("auth.submit");
    let submit_action = ActionUpdateState::create(&mut fbb, &ActionUpdateStateArgs {
        key: Some(submit_key),
        value: None,
    });
    let signin_btn = Button::create(&mut fbb, &ButtonArgs {
        id: Some(btn_id),
        label: Some(btn_label),
        variant: ButtonVariant::Primary,
        on_press_type: StacAction::ActionUpdateState,
        on_press: Some(submit_action.as_union_value()),
        ..Default::default()
    });

    // ── Header ────────────────────────────────────────────────────────────────
    let hdr_id = fbb.create_string("login-header");
    let hdr_title = fbb.create_string("Sign in");
    let header = Header::create(&mut fbb, &HeaderArgs {
        id: Some(hdr_id),
        title: Some(hdr_title),
        ..Default::default()
    });

    // ── Scaffold ──────────────────────────────────────────────────────────────
    let scaf_id = fbb.create_string("login-scaffold");
    let scaffold = Scaffold::create(&mut fbb, &ScaffoldArgs {
        id: Some(scaf_id),
        header_type: StacNode::Header,
        header: Some(header.as_union_value()),
        content_type: StacNode::Card,
        content: Some(login_card.as_union_value()),
        footer_type: StacNode::Button,
        footer: Some(signin_btn.as_union_value()),
        ..Default::default()
    });

    // ── Root ──────────────────────────────────────────────────────────────────
    let root = StacRoot::create(&mut fbb, &StacRootArgs {
        schema_version: 1,
        node_type: StacNode::Scaffold,
        node: Some(scaffold.as_union_value()),
    });
    finish_stac_root_buffer(&mut fbb, root);

    fbb.finished_data().to_vec()
}
