//! Truth snapshots — one read per screen, counts derived from canonical sets.
//!
//! Flutter draws these. It does not keep a second copy of any fact they carry.

use crate::api::{
    AnswerId, AnswerSnapshot, ApiError, ApiResult, CredentialState, Finding, HomeSnapshot,
    KnowledgeSource, MarkState, PrivacyRulesSnapshot, ProviderFact, ProviderSnapshot, ScanOrigin,
    SessionId, TaughtExceptionRow, TaughtValueRow, VaultSnapshot, VaultState, WorkspaceSnapshot,
};
use crate::session::{with_core, Session};

use super::{
    build_payload, document_view, kinds, list_findings, list_tokens, packs, payload_view, profiles,
    restored_view, settings, vault_state,
};

pub(crate) fn home_snapshot() -> ApiResult<HomeSnapshot> {
    let providers = provider_facts()?;
    let vault = vault_state()?;
    let (identity_count, value_count) = vault_counts(vault)?;
    let profiles = if vault == VaultState::Unlocked {
        profiles()?
    } else {
        Vec::new()
    };
    Ok(HomeSnapshot {
        state_revision: truth_revision(),
        vault,
        identity_count,
        value_count,
        profiles,
        packs: packs()?,
        providers,
        settings: settings()?,
        kinds: kinds()?,
    })
}

pub(crate) fn workspace_snapshot(session: SessionId) -> ApiResult<WorkspaceSnapshot> {
    let document = document_view(session)?;
    let findings = list_findings(session)?;
    let tokens = list_tokens(session)?;
    let vault = vault_state()?;
    let (profile_id, scan_origin, revision, answers, can_undo, normal) = with_core(|core| {
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        let answers: Vec<AnswerId> = s.answers.keys().copied().map(|id| AnswerId { id }).collect();
        Ok((
            s.profile_id.clone(),
            s.scan_origin,
            s.revision,
            answers,
            !s.protections.is_empty(),
            s.normal_words,
        ))
    })?;

    let auto_protected = count_findings(&findings, |f| f.state == MarkState::Protected && !f.decided);
    let user_protected = count_findings(&findings, |f| f.state == MarkState::Protected && f.decided);
    let open_suggestions = count_findings(&findings, |f| f.state == MarkState::Suggested);

    let (handle, payload) = match build_payload(session) {
        Ok(h) => {
            let view = payload_view(h)?;
            (Some(h), Some(view))
        }
        Err(ApiError::NothingToSend) => (None, None),
        Err(e) => return Err(e),
    };

    Ok(WorkspaceSnapshot {
        state_revision: truth_revision(),
        session,
        profile_id,
        revision,
        scan_origin,
        auto_protected,
        user_protected,
        open_suggestions,
        normal,
        token_count: tokens.len() as u32,
        can_undo,
        findings,
        document,
        tokens,
        payload,
        handle,
        vault,
        answers,
    })
}

pub(crate) fn vault_snapshot() -> ApiResult<VaultSnapshot> {
    let vault = vault_state()?;
    let (identity_count, value_count, taught_values) = match vault {
        VaultState::Unlocked => taught()?,
        _ => (0, 0, Vec::new()),
    };
    let profiles = if vault == VaultState::Unlocked {
        profiles()?
    } else {
        Vec::new()
    };
    Ok(VaultSnapshot {
        state_revision: truth_revision(),
        vault,
        identity_count,
        value_count,
        profiles,
        can_forget: value_count > 0,
        taught_values,
    })
}

pub(crate) fn privacy_rules_snapshot(profile_id: Option<String>) -> ApiResult<PrivacyRulesSnapshot> {
    let vault = vault_state()?;
    if vault != VaultState::Unlocked {
        return Err(ApiError::VaultLocked);
    }
    with_core(|core| {
        let state_revision = core.state_revision;
        core.vault.with_open(|vault| {
            let include = |row_profile: &Option<String>| match profile_id.as_deref() {
                Some(active) => row_profile.as_deref().is_none_or(|row| row == active),
                None => true,
            };
            let mut values = Vec::new();
            for e in &vault.entities {
                if !include(&e.profile_id) {
                    continue;
                }
                for v in &e.values {
                    values.push(taught_value_row(vault, e, v));
                }
            }
            let mut exceptions = Vec::new();
            for exception in &vault.exceptions {
                if !include(&exception.profile_id) {
                    continue;
                }
                let profile_name = exception
                    .profile_id
                    .as_ref()
                    .and_then(|id| vault.profiles.iter().find(|p| &p.id == id).map(|p| p.name.clone()));
                let scope = profile_name.clone().unwrap_or_else(|| "Everywhere".to_string());
                exceptions.push(TaughtExceptionRow {
                    id: exception.id,
                    value: exception.value.expose().to_string(),
                    kind: exception.kind,
                    profile_id: exception.profile_id.clone(),
                    profile_name,
                    taught_at: exception.learned_at,
                    why: format!("This value is excluded in {scope}."),
                    source: KnowledgeSource::UserException,
                });
            }
            let label_rules: Vec<crate::api::LabelRuleRow> = {
                let mut rows: Vec<crate::api::LabelRuleRow> = vault
                    .label_rules
                    .iter()
                    .filter(|r| include(&r.profile_id))
                    .map(|r| crate::api::LabelRuleRow {
                        id: r.id,
                        label: r.label.clone(),
                        kind: r.kind,
                        profile_id: r.profile_id.clone(),
                        profile_name: r.profile_id.as_ref().and_then(|id| {
                            vault.profiles.iter().find(|p| &p.id == id).map(|p| p.name.clone())
                        }),
                        learned_at: r.learned_at,
                    })
                    .collect();
                rows.sort_by_key(|r| std::cmp::Reverse(r.id));
                rows
            };
            let rule_sets: Vec<crate::api::RuleSetRow> = crate::scanner::sets::all()
                .into_iter()
                .map(|s| crate::api::RuleSetRow {
                    id: s.id.to_string(),
                    label: s.label.to_string(),
                    rules: s.rules.len() as u32,
                })
                .collect();
            // What ran, not what was asked for: a set this build no longer has
            // must not be reported as active (§2 of the invariants).
            let asked: Vec<String> = profile_id
                .as_deref()
                .and_then(|id| vault.profiles.iter().find(|p| p.id == id))
                .map(|p| p.languages.clone())
                .unwrap_or_default();
            let active_sets = crate::scanner::sets::known_of(&asked);
            Ok(PrivacyRulesSnapshot {
                state_revision,
                profile_id,
                values,
                exceptions,
                label_rules,
                rule_sets,
                active_sets,
                rules_built: true,
            })
        })
    })?
}

pub(crate) fn provider_snapshot() -> ApiResult<ProviderSnapshot> {
    Ok(ProviderSnapshot {
        state_revision: truth_revision(),
        providers: provider_facts()?,
    })
}

pub(crate) fn answer_snapshot(session: SessionId, answer: AnswerId) -> ApiResult<AnswerSnapshot> {
    // Position **and** neighbours in one read of one map, so the number a
    // person sees and the answer a press moves to cannot come apart.
    let (index, total, previous, next) = with_core(|core| {
        let s = core.get(session.id).ok_or(ApiError::InvalidSession)?;
        let ids: Vec<u32> = s.answers.keys().copied().collect();
        let total = ids.len() as u32;
        let at = ids
            .iter()
            .position(|id| *id == answer.id)
            .ok_or(ApiError::UnknownToken)?;
        let previous = at.checked_sub(1).and_then(|i| ids.get(i)).map(|id| AnswerId { id: *id });
        let next = ids.get(at + 1).map(|id| AnswerId { id: *id });
        Ok(((at as u32).saturating_add(1), total, previous, next))
    })?;
    Ok(AnswerSnapshot {
        state_revision: truth_revision(),
        answer,
        index,
        total,
        previous,
        next,
        restored: restored_view(session, answer)?,
        as_written: super::ai_view(session, answer)?,
    })
}

fn truth_revision() -> u32 {
    with_core(|core| core.state_revision)
}

fn count_findings(findings: &[Finding], pred: impl Fn(&Finding) -> bool) -> u32 {
    findings.iter().filter(|f| pred(f)).count() as u32
}

fn vault_counts(vault: VaultState) -> ApiResult<(u32, u32)> {
    if vault != VaultState::Unlocked {
        return Ok((0, 0));
    }
    let (identities, values, _) = taught()?;
    Ok((identities, values))
}

fn taught() -> ApiResult<(u32, u32, Vec<TaughtValueRow>)> {
    with_core(|core| {
        core.vault.with_open(|vault| {
            let mut rows = Vec::new();
            for e in &vault.entities {
                for v in &e.values {
                    rows.push(taught_value_row(vault, e, v));
                }
            }
            Ok((vault.entities.len() as u32, rows.len() as u32, rows))
        })
    })?
}

fn taught_value_row(
    vault: &crate::vault::model::Vault,
    entity: &crate::vault::model::Entity,
    value: &crate::vault::model::ValueRecord,
) -> TaughtValueRow {
    let profile_name = entity
        .profile_id
        .as_ref()
        .and_then(|id| vault.profiles.iter().find(|p| &p.id == id).map(|p| p.name.clone()));
    let scope = profile_name.clone().unwrap_or_else(|| "Everywhere".to_string());
    TaughtValueRow {
        entity_id: entity.id,
        entity_label: entity.label.expose().to_string(),
        value_id: value.id,
        value: value.value.expose().to_string(),
        kind: value.kind,
        profile_id: entity.profile_id.clone(),
        profile_name,
        aliases: value.aliases.iter().map(|a| a.expose().to_string()).collect(),
        taught_at: value.learned_at,
        why: format!("You taught Z Privacy this value. Scope: {scope}."),
        source: KnowledgeSource::UserTaughtValue,
    }
}

pub(crate) fn provider_facts() -> ApiResult<Vec<ProviderFact>> {
    let mut rows = Vec::new();
    for provider in crate::providers::known() {
        let sealed = super::login_in_vault(provider.id());
        let in_session = with_core(|core| core.session_logins.get(provider.id()).cloned());
        let credential_state = if sealed.is_some() {
            CredentialState::EncryptedInVault
        } else if in_session.is_some() {
            CredentialState::SessionOnly
        } else {
            CredentialState::Missing
        };
        let login = sealed.clone().or_else(|| in_session.clone());
        let connected = login
            .as_ref()
            .is_some_and(|l| super::login_is_usable(provider.as_ref(), l));
        rows.push(ProviderFact {
            id: provider.id().to_string(),
            label: provider.label().to_string(),
            configured: credential_state != CredentialState::Missing,
            connected,
            endpoint: login
                .as_ref()
                .map(|l| l.base.clone())
                .unwrap_or_else(|| provider.default_base().to_string()),
            model: login
                .as_ref()
                .map(|l| l.model.clone())
                .unwrap_or_else(|| provider.default_model().to_string()),
            credential_required: provider.credential_required(
                login
                    .as_ref()
                    .map(|l| l.base.as_str())
                    .unwrap_or_else(|| provider.default_base()),
            ),
            credential_state,
        });
    }
    Ok(rows)
}

pub(crate) fn mark_scanned(s: &mut Session) {
    s.scan_origin = if s.scan_origin == ScanOrigin::NotScanned {
        ScanOrigin::OnImport
    } else {
        ScanOrigin::Rescan
    };
}

/// Always / Profile need an open vault. Named so a press cannot look like success.
pub(crate) fn require_open_vault() -> ApiResult<()> {
    match vault_state()? {
        VaultState::Unlocked => Ok(()),
        _ => Err(ApiError::VaultRequired),
    }
}
