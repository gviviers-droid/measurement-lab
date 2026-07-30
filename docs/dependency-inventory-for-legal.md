# Internet Measurements Lab: dependency and licence inventory

**Prepared for:** Legal review, RIPE NCC
**Prepared by:** Learning & Development
**Date:** 27 July 2026
**Version:** 1.0
**Subject:** The hands-on lab environment accompanying Unit 2 of the Internet Measurements e-learning course

---

## 1. Purpose

This document lists every third-party software component the lab depends on, states the licence and governing body of each, and assesses what happens to RIPE NCC's ability to deliver the course if any of those components becomes unavailable.

It exists to answer one question: can this learning material be delivered to the RIPE community indefinitely, without depending on any third-party service that could be withdrawn, restricted, geo-blocked or made subject to export control?

This document is a technical inventory prepared to support legal review. It is not legal advice, and the export control observations in section 8 are offered as a starting point for Legal's own assessment rather than as a conclusion.

## 2. Summary of findings

The lab can be delivered with no runtime dependency on any third-party service. Every functional component is licensed under an OSI-approved open source licence, and all of them can be mirrored onto RIPE NCC infrastructure and served from there indefinitely.

Two items need a decision before sign-off, both concerning optional convenience routes rather than the lab itself. They are listed in section 6.

One finding is relevant to an internal discussion about tooling: the alternative approach based on Vagrant and VirtualBox, used by the IPv6 Advanced course, scores worse against this same test than the container-based approach proposed here. Section 7 sets out the comparison.

## 3. The test being applied

The relevant distinction is between depending on a **service** and depending on an **artefact under an open source licence**.

A service can be withdrawn, priced differently, geo-blocked, made subject to export control, or simply switched off. The provider is under no obligation to continue offering it, and the user has no remedy.

An open source licence grant works differently. Once RIPE NCC holds a copy of the source code or a built artefact, the rights to use, modify and redistribute it are perpetual and cannot be retracted by the upstream project, its owner, or a subsequent acquirer of that owner. The upstream project can stop publishing new versions; it cannot take away what has already been published and copied.

The test applied throughout this document is therefore twofold:

1. Is the component under an OSI-approved open source licence?
2. Can RIPE NCC hold and serve its own copy, so that delivery does not require reaching any third party at course-delivery time?

A component passes only if the answer to both is yes.

## 4. Component inventory

### 4.1 Components that run inside the lab

| Component | Role in the lab | Licence | Governance | Source |
|---|---|---|---|---|
| FRRouting (FRR) | Routing software on all 10 routers; provides BGP, OSPF, OSPFv3 | GPL-2.0-or-later | FRRouting project, a Linux Foundation project | [frrouting.org](https://frrouting.org) |
| network-multitool (srl-labs) | Container image for the workstation and server nodes; bundles ping, traceroute, mtr, iperf3 | MIT | srl-labs, community project | [github.com/srl-labs/network-multitool](https://github.com/srl-labs/network-multitool) |
| iputils (ping) | Latency measurement | GPL-2.0-or-later / BSD-3-Clause components | iputils project | [github.com/iputils/iputils](https://github.com/iputils/iputils) |
| traceroute | Path discovery | GPL-2.0-or-later | Dmitry Butskoy / Linux distributions | Debian and Alpine package archives |
| mtr | Combined per-hop loss and latency measurement | GPL-2.0-or-later | traviscross/mtr community project | [github.com/traviscross/mtr](https://github.com/traviscross/mtr) |
| iperf3 | Generates the background traffic used in the congestion activity | BSD-3-Clause | ESnet / Lawrence Berkeley National Laboratory | [github.com/esnet/iperf](https://github.com/esnet/iperf) |
| Linux kernel netem / tc | Applies the delay, jitter, loss and rate limits that make the measurements meaningful | GPL-2.0 | Linux kernel, Linux Foundation | Present in every Linux distribution |

### 4.2 Components that run the lab

| Component | Role | Licence | Governance | Source |
|---|---|---|---|---|
| Containerlab | Builds the topology, wires the virtual links, manages lab lifecycle | BSD-3-Clause | srl-labs community project, originated at Nokia (Finland) | [github.com/srl-labs/containerlab](https://github.com/srl-labs/containerlab) |
| Container engine: Podman (recommended) | Runs the containers | Apache-2.0 | Containers organisation, originated at Red Hat | [podman.io](https://podman.io) |
| Container engine: Docker Engine (alternative) | Runs the containers | Apache-2.0 | Moby project | [github.com/moby/moby](https://github.com/moby/moby) |
| Linux (learner's own or inside a VM) | Host operating system | GPL-2.0 and others | Linux Foundation and distributions | Distribution of choice |
| QEMU / libvirt (only if a VM wrapper is used) | Open source hypervisor for the optional VM route | GPL-2.0 / LGPL-2.1 | QEMU project, Software Freedom Conservancy | [qemu.org](https://www.qemu.org) |

### 4.3 Components used to build the material, not to run it

These are used by RIPE NCC staff when producing the lab. Learners never need them.

| Component | Role | Licence |
|---|---|---|
| Python 3 | Runs the frontend build script | PSF License (OSI-approved) |
| Python-Markdown | Converts the activity sheets to the learner-facing HTML | BSD-3-Clause |

### 4.4 Material produced by RIPE NCC

The topology definition, all router configurations, all scripts, the five activity sheets, the cheatsheet, the topology diagram and the learner-facing frontend are original work produced by RIPE NCC and carry no third-party rights. They contain no third-party code and no copied documentation.

The learner-facing frontend is a single self-contained HTML file. It loads no fonts, scripts, stylesheets or images from any external source, and functions with no network connection at all.

## 5. Network identifiers used

The lab uses only address space and identifiers that the relevant registries have reserved for exactly this purpose, so no real-world resources are used and nothing the lab does can affect the live Internet even if a learner's machine were misconfigured.

| Resource | Used in the lab | Reserved by |
|---|---|---|
| 3fff::/20 | All IPv6 addressing | [RFC 9637](https://www.rfc-editor.org/rfc/rfc9637), IPv6 documentation prefix |
| 10.0.0.0/8 | Private IPv4 addressing inside each network | [RFC 1918](https://www.rfc-editor.org/rfc/rfc1918) |
| 100.64.0.0/10 | IPv4 addressing on inter-network links | [RFC 6598](https://www.rfc-editor.org/rfc/rfc6598), shared address space |
| AS 65001 to AS 65100 | All autonomous system numbers | [RFC 6996](https://www.rfc-editor.org/rfc/rfc6996), private-use ASNs |

## 6. Items requiring a decision

Neither item affects the lab itself. Both concern optional convenience routes that can be dropped without loss of function.

**6.1 GitHub Codespaces.** Originally offered as a zero-install route. It is a cloud service, and therefore fails the test in section 3. **Recommendation: drop it.** The lab runs identically without it and no functionality is lost.

**6.2 The VS Code Dev Containers extension.** The Dev Container *specification* is open ([containers.dev](https://containers.dev)) and the reference CLI is MIT-licensed, but Microsoft's branded VS Code build and the Dev Containers extension are distributed under proprietary Microsoft terms, through a Microsoft-operated marketplace. This route is a convenience for learners on Windows and macOS, not a requirement. **Recommendation: keep it as an optional, clearly-labelled convenience, and make the fully open source route (Podman or Docker Engine plus Containerlab, or the VM wrapper) the documented default.** If Legal prefers no proprietary component at all in the documented paths, the extension route can be removed with no effect on the lab.

**6.3 Docker Desktop, if used.** Docker Engine is Apache-2.0 and free. Docker Desktop, the graphical bundle for Windows and macOS, is proprietary and requires a paid subscription for organisations above a size threshold set by Docker Inc. Many of our learners work at organisations above that threshold. **Recommendation: document Podman and Podman Desktop (both Apache-2.0) as the primary container engine, and mention Docker only as an alternative learners may already have.**

## 7. Comparison with the Vagrant approach

The IPv6 Advanced course distributes its lab as a Vagrant box run under VirtualBox. If the same approach were used for this course, it would score as follows against the section 3 test.

| Criterion | Container approach (proposed) | Vagrant and VirtualBox approach |
|---|---|---|
| Licence of the orchestration tool | Containerlab, BSD-3-Clause, OSI-approved | Vagrant, Business Source License 1.1 since August 2023. Source-available, with conditions on commercial use. Not an OSI-approved open source licence |
| Licence of the execution layer | Podman, Apache-2.0 | VirtualBox base package GPL-3.0; Extension Pack under a proprietary Oracle licence |
| Default distribution channel | Container registry, mirrorable to RIPE NCC infrastructure | HCP Vagrant Registry, operated by HashiCorp, now part of IBM. Self-hosting a box is possible but is not the documented default |
| Architecture coverage | One multi-arch artefact covers Intel and Apple Silicon | A VM image is architecture-specific. Two builds, two test cycles and two sets of instructions are needed, indefinitely |
| Artefact size to distribute | Roughly 400 MB of container images | Roughly 2 GB per VM image, so roughly 4 GB across two architectures |
| Corporate control of upstream | Distributed community projects across several jurisdictions | Two single corporate owners: IBM (Vagrant) and Oracle (VirtualBox) |

The point most relevant to Legal's concern: the licence change in August 2023 means Vagrant is no longer open source, and both the tool and the default distribution channel are now controlled by a single US corporation. The proposed container approach depends on no single corporate owner and every component remains OSI-approved.

## 8. Export control observations

These observations are offered to assist Legal's own assessment and are not a legal conclusion.

The concern that prompted this review is that a service can be withdrawn to comply with export controls, as happened when access to a commercial AI service was suspended in June 2026 to comply with US Department of Commerce controls and restored the following month.

The published-software provisions of the US Export Administration Regulations appear directly relevant to why open source components sit in a different category. Under EAR §734.7, technology and software that has been made available to the public without restrictions on further dissemination is "published" and is therefore not subject to the EAR. The Linux Foundation has published a whitepaper applying this specifically to open source projects, which may be a useful reference for the review: [Understanding US export controls with open source projects](https://www.linuxfoundation.org/resources/publications/understanding-us-export-controls-with-open-source-projects). The regulation itself is at [bis.gov/regulations/ear/734](https://www.bis.gov/regulations/ear/734).

Two points Legal may wish to test:

- Whether the "published" status of the specific components listed in section 4 holds, given that all of them are distributed publicly without restriction on redistribution.
- Whether holding RIPE NCC's own mirrored copies materially strengthens the position, on the basis that delivery would then not depend on any US-operated distribution point at course-delivery time.

## 9. Continuity analysis

The question for each upstream: if it disappeared tomorrow, could RIPE NCC still deliver this course?

| If this became unavailable | Effect on delivery | Why |
|---|---|---|
| The container registries (quay.io, ghcr.io) | None | Images are mirrored to RIPE NCC infrastructure and pinned by cryptographic digest. Registries are only needed when we choose to update |
| The Containerlab project | None in the short or medium term | We hold the binary and its BSD-3-Clause source. It is a self-contained Go binary with no runtime service dependency |
| The FRRouting project | None in the short or medium term | We hold the images and the GPL-2.0 source |
| GitHub | None | Only used for upstream source; nothing at delivery time depends on it |
| Any single upstream vendor changing its licence | None for versions already held | A licence change applies to future releases. Rights already granted for the versions we hold cannot be withdrawn |
| The learner's Internet connection | None once the bundle is downloaded | The lab and its frontend run entirely offline |

## 10. Proposed conditions of approval

If Legal is satisfied, the following are the technical controls that make the assessment above hold in practice, and can be adopted as conditions:

1. All container images are mirrored to RIPE NCC-operated storage and served from there. Learners are never directed to a third-party registry.
2. Every image is pinned by cryptographic digest rather than by version tag, so the artefact a learner receives is exactly the one reviewed and cannot be changed upstream.
3. The lab archive, image bundle and frontend are distributed from RIPE NCC infrastructure, with published checksums.
4. A full copy of the source of each open source component, together with its licence text, is retained by RIPE NCC in line with the obligations of GPL-2.0 and the notice requirements of BSD-3-Clause, MIT and Apache-2.0.
5. Attribution and licence notices for all components are included in the distributed bundle.
6. No component of the delivered lab makes outbound network connections at runtime. This is verifiable and should be re-verified before each course release.
7. The documented default installation route uses only OSI-approved open source components.

## 11. Verification steps before sign-off

The following should be completed and the results attached to this document:

- Confirm the exact image digests to be mirrored, and record them here.
- Extract the licence texts from inside the two container images and confirm they match the licences stated in section 4.
- Run a network capture during a full lab session to confirm condition 6 holds in practice.
- Confirm with Legal whether the Dev Containers convenience route in section 6.2 may remain in the documentation.

## 12. Sources

- Containerlab licence: [github.com/srl-labs/containerlab](https://github.com/srl-labs/containerlab)
- FRRouting: [frrouting.org](https://frrouting.org)
- network-multitool: [github.com/srl-labs/network-multitool](https://github.com/srl-labs/network-multitool)
- Podman: [podman.io](https://podman.io)
- Vagrant licence change: [hashicorp.com/blog/hashicorp-adopts-business-source-license](https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license)
- Vagrant Cloud migration to HCP: [hashicorp.com/blog/vagrant-cloud-is-moving-to-hcp](https://www.hashicorp.com/en/blog/vagrant-cloud-is-moving-to-hcp)
- EAR Part 734: [bis.gov/regulations/ear/734](https://www.bis.gov/regulations/ear/734)
- Linux Foundation export control whitepaper: [linuxfoundation.org](https://www.linuxfoundation.org/resources/publications/understanding-us-export-controls-with-open-source-projects)

## Change log

| Version | Date | Change |
|---|---|---|
| 1.0 | 27 July 2026 | First version prepared for legal review |
