// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp

import juce_cmp.events.EventSender
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.PrintStream

/**
 * Main entry point for the juce_cmp library.
 *
 * Client applications MUST call init() as the very first thing in main(),
 * before any other code runs. This sets up stdout capture for binary IPC.
 */
object Library {
    private var initialized = false

    /**
     * Initialize the juce_cmp library.
     *
     * MUST be called as the very first thing in main(), before any
     * library initialization or other code that might print to stdout.
     *
     * This performs critical setup:
     * - Captures raw stdout (fd 1) for binary IPC with the host
     * - Redirects System.out to stderr so library noise doesn't corrupt the protocol
     */
    fun init() {
        if (initialized) return
        initialized = true

        // Capture the raw stdout before anyone else can pollute it
        // FileDescriptor.out is the JVM's reference to fd 1
        EventSender.setOutput(FileOutputStream(FileDescriptor.out))

        // Redirect System.out to stderr so library noise doesn't corrupt our protocol
        // All println(), library warnings, etc. will now go to stderr
        System.setOut(PrintStream(FileOutputStream(FileDescriptor.err), true))
    }
}
