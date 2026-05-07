use flatbuffers::FlatBufferBuilder;
use zeroflat_fbs::fbs::zeroflat::{
    ActionUpdateState, ActionUpdateStateArgs,
    Card, CardArgs,
    Header, HeaderArgs,
    Scaffold, ScaffoldArgs,
    StacAction, StacNode, StacRoot, StacRootArgs,
    Switch, SwitchArgs,
    finish_stac_root_buffer,
};

/// Builds a Settings screen FlatBuffer and returns the serialized bytes.
///
/// Tree: StacRoot → Scaffold
///   header  → Header ("Settings")
///   content → Card ("Preferences") → Switch (notifications-switch)
pub fn build() -> Vec<u8> {
    let mut fbb = FlatBufferBuilder::with_capacity(512);

    // ── Notifications Switch ──────────────────────────────────────────────────
    let sw_id = fbb.create_string("notifications-switch");
    let sw_label = fbb.create_string("Notifications");
    let sw_desc = fbb.create_string("Get pushes when peers sync.");
    let sw_key = fbb.create_string("settings.notifications");
    let sw_action = ActionUpdateState::create(&mut fbb, &ActionUpdateStateArgs {
        key: Some(sw_key),
        value: None,
    });
    let notif_switch = Switch::create(&mut fbb, &SwitchArgs {
        id: Some(sw_id),
        label: Some(sw_label),
        description: Some(sw_desc),
        value: true,
        enabled: true,
        on_change_type: StacAction::ActionUpdateState,
        on_change: Some(sw_action.as_union_value()),
        ..Default::default()
    });

    // ── Card wrapping the switch ──────────────────────────────────────────────
    let card_id = fbb.create_string("settings-card");
    let card_title = fbb.create_string("Preferences");
    let card_subtitle = fbb.create_string("Adjust your preferences.");
    let settings_card = Card::create(&mut fbb, &CardArgs {
        id: Some(card_id),
        title: Some(card_title),
        subtitle: Some(card_subtitle),
        child_type: StacNode::Switch,
        child: Some(notif_switch.as_union_value()),
        ..Default::default()
    });

    // ── Header ────────────────────────────────────────────────────────────────
    let hdr_id = fbb.create_string("settings-header");
    let hdr_title = fbb.create_string("Settings");
    let header = Header::create(&mut fbb, &HeaderArgs {
        id: Some(hdr_id),
        title: Some(hdr_title),
        ..Default::default()
    });

    // ── Scaffold ──────────────────────────────────────────────────────────────
    let scaf_id = fbb.create_string("settings-scaffold");
    let scaffold = Scaffold::create(&mut fbb, &ScaffoldArgs {
        id: Some(scaf_id),
        header_type: StacNode::Header,
        header: Some(header.as_union_value()),
        content_type: StacNode::Card,
        content: Some(settings_card.as_union_value()),
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
